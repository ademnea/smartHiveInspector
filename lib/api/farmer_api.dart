import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:HPGM/config/api_config.dart';
import 'package:HPGM/Services/token_storage.dart';

/// An error returned by the farmer API, or a network failure (status 0).
class ApiException implements Exception {
  final int status;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException(this.status, this.message, [this.errors]);

  bool get isNetworkError => status == 0;

  /// First validation message for [field] from a 422 response.
  String? fieldError(String field) {
    final list = errors?[field];
    return list is List && list.isNotEmpty ? list.first.toString() : null;
  }

  @override
  String toString() => message;
}

/// One page of a paginated list.
///
/// Handles both response envelopes:
///  A: {success, message, data: {data: [...], current_page, last_page, total}}
///  B: {data: [...], meta: {current_page, last_page, total}}
class ApiPage<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  ApiPage(this.items, this.currentPage, this.lastPage, this.total);

  bool get hasMore => currentPage < lastPage;

  factory ApiPage.from(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final isB = json['meta'] != null;
    final list = (isB ? json['data'] : json['data']['data']) as List;
    final meta = (isB ? json['meta'] : json['data']) as Map<String, dynamic>;
    return ApiPage(
      list.map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      (meta['current_page'] as num?)?.toInt() ?? 1,
      (meta['last_page'] as num?)?.toInt() ?? 1,
      (meta['total'] as num?)?.toInt() ?? list.length,
    );
  }
}

/// Client for the farmer API (`/api/v1/farmer`).
class FarmerApi {
  static final FarmerApi instance = FarmerApi._();
  FarmerApi._();

  static http.Client _client = http.Client();

  @visibleForTesting
  static void setHttpClientForTesting(http.Client client) => _client = client;

  @visibleForTesting
  static void resetHttpClientForTesting() => _client = http.Client();

  /// Called after any 401 on a protected route, once the session is cleared.
  /// main.dart points this at the login screen.
  static void Function()? onUnauthorized;

  static const _timeout = Duration(seconds: 20);
  static const _publicPaths = {
    '/login',
    '/register',
    '/password/forgot',
    '/password/reset',
  };

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? query,
  }) async {
    final isPublic = _publicPaths.contains(path);
    final token = isPublic ? null : await TokenStorage.getToken();
    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );

    final request = http.Request(method, uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response res;
    try {
      res = await http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on TimeoutException {
      throw ApiException(0, 'The server took too long to respond.');
    } on SocketException {
      throw ApiException(0, 'Cannot reach the server. Check your connection.');
    } on http.ClientException {
      throw ApiException(0, 'Cannot reach the server. Check your connection.');
    }

    dynamic data;
    try {
      data = res.body.isEmpty ? null : jsonDecode(res.body);
    } on FormatException {
      data = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    if (res.statusCode == 401 && !isPublic) {
      await TokenStorage.clearLoginData();
      onUnauthorized?.call();
    }

    final map = data is Map<String, dynamic> ? data : const {};
    throw ApiException(
      res.statusCode,
      map['message']?.toString() ?? _defaultMessage(res.statusCode),
      map['errors'] is Map<String, dynamic> ? map['errors'] : null,
    );
  }

  static String _defaultMessage(int status) {
    if (status >= 500) return 'Server error. Please try again.';
    return 'Something went wrong (HTTP $status).';
  }

  // ---- Auth ----

  /// Registers a farmer account. The account must be approved by an admin
  /// before it can log in; no token is returned.
  Future<String?> register({
    required String name,
    required String email,
    required String telephone,
    required String password,
    required String passwordConfirmation,
    String? firstName,
    String? lastName,
  }) async {
    final data = await _send('POST', '/register', body: {
      'name': name,
      'email': email,
      'telephone': telephone,
      'password': password,
      'password_confirmation': passwordConfirmation,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
    });
    return data is Map ? data['message']?.toString() : null;
  }

  /// Logs in and stores the session. Returns the farmer map.
  /// Throws [ApiException] with 403 for accounts that are not farmers.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _send(
      'POST',
      '/login',
      body: {'email': email, 'password': password},
    ) as Map<String, dynamic>;

    final farmer = Map<String, dynamic>.from(data['farmer'] as Map);
    final role = farmer['role']?.toString();
    if (role != null && role != 'farmer') {
      throw ApiException(403, 'This app is for farmer accounts only.');
    }

    await TokenStorage.saveLoginData(
      token: data['token'] as String,
      expiresAt: DateTime.tryParse(data['expires_at']?.toString() ?? ''),
      userId: farmer['id']?.toString(),
      username: farmer['email']?.toString() ?? email,
      displayName: farmer['name']?.toString(),
      role: role ?? 'farmer',
      profile: farmer,
    );
    return farmer;
  }

  /// Revokes the token on the server. Local data is cleared even if the
  /// call fails.
  Future<void> logout() async {
    try {
      await _send('POST', '/logout');
    } catch (_) {
      // The local session is cleared below regardless.
    } finally {
      await TokenStorage.clearLoginData();
    }
  }

  Future<String?> forgotPassword(String email) async {
    final data = await _send('POST', '/password/forgot', body: {'email': email});
    return data is Map ? data['message']?.toString() : null;
  }

  Future<String?> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await _send('POST', '/password/reset', body: {
      'email': email,
      'token': token,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
    return data is Map ? data['message']?.toString() : null;
  }

  // ---- Profile & push ----

  Future<Map<String, dynamic>> profile() async =>
      Map<String, dynamic>.from((await _send('GET', '/profile'))['data']);

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> fields) async =>
      Map<String, dynamic>.from(
        (await _send('PUT', '/profile', body: fields))['data'],
      );

  Future<void> registerDeviceToken(String fcmToken) =>
      _send('POST', '/device-token', body: {'device_token': fcmToken});

  // ---- Apiaries & hives (envelope B) ----

  Future<ApiPage<Map<String, dynamic>>> apiaries({
    int page = 1,
    int perPage = 25,
  }) async => ApiPage.from(
    await _send('GET', '/apiaries', query: {'page': page, 'per_page': perPage}),
    (e) => e,
  );

  Future<ApiPage<Map<String, dynamic>>> hives(
    int apiaryId, {
    int page = 1,
    int perPage = 25,
  }) async => ApiPage.from(
    await _send(
      'GET',
      '/apiaries/$apiaryId/hives',
      query: {'page': page, 'per_page': perPage},
    ),
    (e) => e,
  );

  /// Every apiary, following pagination to the last page.
  Future<List<Map<String, dynamic>>> allApiaries() =>
      _collect((page) => apiaries(page: page, perPage: 100));

  /// Every hive in [apiaryId], following pagination to the last page.
  Future<List<Map<String, dynamic>>> allHives(int apiaryId) =>
      _collect((page) => hives(apiaryId, page: page, perPage: 100));

  Future<List<T>> _collect<T>(Future<ApiPage<T>> Function(int page) fetch) async {
    final items = <T>[];
    var page = 1;
    while (true) {
      final result = await fetch(page);
      items.addAll(result.items);
      if (!result.hasMore) return items;
      page++;
    }
  }

  // ---- Sensor data (envelope A) ----

  Future<Map<String, dynamic>> latest(int hiveId) async =>
      Map<String, dynamic>.from((await _send('GET', '/hives/$hiveId/latest'))['data']);

  /// [type]: temperature | humidity | carbondioxide | weight.
  /// Results come newest first.
  Future<ApiPage<Map<String, dynamic>>> readings(
    int hiveId,
    String type, {
    DateTime? from,
    DateTime? to,
    int perPage = 50,
    int page = 1,
  }) async => ApiPage.from(
    await _send('GET', '/hives/$hiveId/$type', query: {
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'per_page': perPage,
      'page': page,
    }),
    (e) => e,
  );

  // ---- Media & inspections (envelope B) ----

  /// [kind]: photos | audio | videos. Each item has a ready-to-load `url`.
  Future<ApiPage<Map<String, dynamic>>> media(
    int hiveId,
    String kind, {
    int page = 1,
  }) async => ApiPage.from(
    await _send('GET', '/hives/$hiveId/$kind', query: {'page': page}),
    (e) => e,
  );

  Future<ApiPage<Map<String, dynamic>>> inspections(
    int hiveId, {
    int page = 1,
  }) async => ApiPage.from(
    await _send('GET', '/hives/$hiveId/inspections', query: {'page': page}),
    (e) => e,
  );

  // ---- Alerts & messages (envelope A) ----

  Future<ApiPage<Map<String, dynamic>>> alerts({int page = 1}) async =>
      ApiPage.from(await _send('GET', '/alerts', query: {'page': page}), (e) => e);

  Future<void> markAlertRead(int alertId) =>
      _send('PATCH', '/alerts/$alertId/read');

  Future<ApiPage<Map<String, dynamic>>> messages({int page = 1}) async =>
      ApiPage.from(await _send('GET', '/messages', query: {'page': page}), (e) => e);

  Future<void> sendMessage(String subject, String message, {int? hiveId}) =>
      _send('POST', '/messages', body: {
        'subject': subject,
        'message': message,
        if (hiveId != null) 'hive_id': hiveId,
      });
}
