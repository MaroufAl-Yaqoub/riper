import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';

class EvidenceApiService {
  Future<void> uploadEvidence({
    required int incidentId,
    required int actorUserId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/incidents/$incidentId/evidence',
    ).replace(queryParameters: {
      'actor_user_id': actorUserId.toString(),
    });

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

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('فشل في رفع الدليل: $body');
    }
  }
}