import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';

class DeepfakeApiResult {
  final int? scanId;
  final int? userId;
  final String fileName;
  final String result;
  final double confidence;
  final DateTime createdAt;

  const DeepfakeApiResult({
    this.scanId,
    this.userId,
    required this.fileName,
    required this.result,
    required this.confidence,
    required this.createdAt,
  });

  factory DeepfakeApiResult.fromJson(Map<String, dynamic> json) {
    return DeepfakeApiResult(
      scanId: json['scan_id'] as int?,
      userId: json['user_id'] as int?,
      fileName: (json['file_name'] ?? '').toString(),
      result: (json['result'] ?? 'Unknown').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toHistoryPayload(int userId) {
    return {
      'user_id': userId,
      'file_name': fileName,
      'result': result,
      'confidence': confidence,
    };
  }

  String get createdAtLabel {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

class DeepfakeApiService {
  Future<DeepfakeApiResult> analyzeImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/deepfake/analyze');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
        ),
      );

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('فشل تحليل الصورة: $body');
    }

    return DeepfakeApiResult.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
  }

  Future<DeepfakeApiResult> saveScan({
    required int userId,
    required DeepfakeApiResult result,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/deepfake/history');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(result.toHistoryPayload(userId)),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('فشل حفظ سجل الفحص: ${response.body}');
    }

    return DeepfakeApiResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<DeepfakeApiResult>> getHistory({
    required int userId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/deepfake/history?user_id=$userId',
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('فشل جلب سجل الفحوصات: ${response.body}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) return [];

    return decoded
        .map((item) => DeepfakeApiResult.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearHistory({
    required int userId,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/deepfake/history?user_id=$userId',
    );

    final response = await http.delete(uri);

    if (response.statusCode != 200) {
      throw Exception('فشل مسح سجل الفحوصات: ${response.body}');
    }
  }
}