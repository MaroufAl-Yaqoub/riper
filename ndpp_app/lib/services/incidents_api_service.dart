import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../models/incident_report.dart';
import '../models/incident_update.dart';
import '../models/incident_analysis.dart';
class IncidentsApiService {
  final http.Client _client = http.Client();

  Future<List<IncidentReport>> getIncidents() async {
    final response = await _client.get(
      Uri.parse(ApiConfig.incidents()),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('فشل في جلب البلاغات');
    }

    final data = jsonDecode(response.body) as List;
    return data
        .map((e) => IncidentReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<IncidentReport> getIncidentById(int incidentId) async {
  final response = await _client.get(
    Uri.parse(
      '${ApiConfig.baseUrl}/incidents/$incidentId?actor_user_id=${ApiConfig.reporterUserId}',
    ),
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode != 200) {
    throw Exception('فشل في جلب تفاصيل البلاغ: ${response.body}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return IncidentReport.fromJson(data);
}

  Future<List<IncidentUpdate>> getIncidentUpdates(int incidentId) async {
  final response = await _client.get(
    Uri.parse(
      '${ApiConfig.baseUrl}/incidents/$incidentId/updates?actor_user_id=${ApiConfig.reporterUserId}',
    ),
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode != 200) {
    throw Exception('فشل في جلب تحديثات البلاغ: ${response.body}');
  }

  final decoded = jsonDecode(response.body);

  if (decoded is List) {
    return decoded
        .map((e) => IncidentUpdate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  return [];
}

  Future<IncidentReport> createIncident({
    required String title,
    required String description,
    required int reportTypeId,
    String? suspiciousUrl,
    String? suspiciousMessage,
    String? platform,
    String? deviceType,
    String? note,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.incidents()),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "reporter_user_id": ApiConfig.reporterUserId,
        "title": title,
        "description": description,
        "report_type_id": reportTypeId,
        "incident_date": DateTime.now().toIso8601String(),
        if (suspiciousUrl != null && suspiciousUrl.isNotEmpty)
          "suspicious_url": suspiciousUrl,
        if (suspiciousMessage != null && suspiciousMessage.isNotEmpty)
          "suspicious_message": suspiciousMessage,
        if (platform != null && platform.isNotEmpty)
          "platform": platform,
        if (deviceType != null && deviceType.isNotEmpty)
          "device_type": deviceType,
        if (note != null && note.isNotEmpty) "note": note,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('فشل في إرسال البلاغ: ${response.body}');
    }

    return IncidentReport.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
  Future<Map<String, dynamic>> analyzeIncident(int incidentId) async {
  final response = await _client.post(
    Uri.parse('${ApiConfig.baseUrl}/incidents/$incidentId/analyze'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'actor_user_id': ApiConfig.reporterUserId,
      'note': 'AI analysis requested from Flutter app',
    }),
  );

  if (response.statusCode != 200) {
    throw Exception('فشل تحليل البلاغ: ${response.body}');
  }

  return jsonDecode(response.body) as Map<String, dynamic>;
}

Future<IncidentAnalysis?> getLatestAnalysis(int incidentId) async {
  final response = await _client.get(
    Uri.parse(
      '${ApiConfig.baseUrl}/incidents/$incidentId/analysis?actor_user_id=${ApiConfig.reporterUserId}',
    ),
    headers: {'Content-Type': 'application/json'},
  );

  if (response.statusCode == 404) {
    return null;
  }

  if (response.statusCode != 200) {
    throw Exception('فشل جلب نتيجة التحليل: ${response.body}');
  }

  return IncidentAnalysis.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}
  Future<void> uploadEvidence({
  required int incidentId,
  required List<int> bytes,
  required String fileName,
}) async {
  final uri = Uri.parse(
    '${ApiConfig.baseUrl}/incidents/$incidentId/evidence?actor_user_id=${ApiConfig.reporterUserId}',
  );

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
    throw Exception('فشل رفع الملف: $body');
  }
}

}