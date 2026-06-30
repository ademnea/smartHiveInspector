import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CsvExportService {
  static Future<void> shareCsv({
    required BuildContext context,
    required String filePrefix,
    required List<String> headers,
    required List<List<String>> rows,
    String? shareText,
    String emptyMessage = 'No data available to export.',
  }) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emptyMessage),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${tempDir.path}/$filePrefix$timestamp.csv');

      final csv = StringBuffer()..writeln(headers.map(_escape).join(','));
      for (final row in rows) {
        csv.writeln(row.map(_escape).join(','));
      }

      await file.writeAsString(csv.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: shareText ?? 'Hive data export',
        subject: file.uri.pathSegments.last,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export data: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  static String _escape(String value) {
    final escaped = value.replaceAll('"', '""');
    final shouldQuote =
        escaped.contains(',') ||
        escaped.contains('\n') ||
        escaped.contains('"');
    return shouldQuote ? '"$escaped"' : escaped;
  }
}
