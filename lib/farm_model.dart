class Farm {
  final int id;
  final int ownerId;
  final String name;
  final String district;
  final String address;
  final double? average_temperature;
  final double? average_weight;
  final double? honeypercent;
  final double? latitude;
  final double? longitude;
  final String? description;
  final String? createdAt;
  final String? updatedAt;
  final int? hivesCount;

  // Farmer API fields.
  final String? apiaryCode;
  final String? country;
  final String? region;
  final String? managingEntity;

  /// One of Active, Inactive, Under Maintenance.
  final String? status;

  Farm({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.district,
    required this.average_temperature,
    required this.average_weight,
    required this.honeypercent,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
    this.hivesCount,
    this.apiaryCode,
    this.country,
    this.region,
    this.managingEntity,
    this.status,
  });

  // Accepts both the old API's farm shape and the farmer API's apiary shape,
  // which may leave out owner, district and address.
  factory Farm.fromJson(Map<String, dynamic> json) {
    return Farm(
      id: _toInt(json['id']) ?? 0,
      ownerId:
          _toInt(json['farmer_id'] ?? json['ownerId'] ?? json['OwnerId']) ?? 0,
      name: json['name']?.toString() ?? 'Unnamed apiary',
      // The farmer API has no address and often no district, so the screens'
      // "district, address" line falls back to "region, country".
      district: (json['district'] ?? json['region'])?.toString() ?? '',
      address: (json['address'] ?? json['country'])?.toString() ?? '',
      average_temperature: _toDouble(json['average_temperature']),
      average_weight: _toDouble(json['average_weight']),
      honeypercent: _toDouble(json['average_honey_percentage']),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      description: json['description']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      hivesCount: _toInt(json['hives_count']),
      apiaryCode: json['apiary_code']?.toString(),
      country: json['country']?.toString(),
      region: json['region']?.toString(),
      managingEntity: json['managing_entity']?.toString(),
      status: json['status']?.toString(),
    );
  }

  static int? _toInt(dynamic v) =>
      v is num ? v.toInt() : int.tryParse(v?.toString() ?? '');

  static double? _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerId': ownerId,
      'name': name,
      'district': district,
      'address': address,
      'average_temperature': average_temperature,
      'average_weight': average_weight,
      'average_honey_percentage': honeypercent,
      'latitude': latitude,
      'longitude': longitude, // Fixed typo from 'longtitude'
      'description': description,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'hives_count': hivesCount,
      'apiary_code': apiaryCode,
      'country': country,
      'region': region,
      'managing_entity': managingEntity,
      'status': status,
    };
  }
}
