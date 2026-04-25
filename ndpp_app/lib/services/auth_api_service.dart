import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/api_config.dart';

class AuthApiService {
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/auth/login');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode != 200) {
      throw Exception(data['detail'] ?? 'فشل تسجيل الدخول');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['access_token']);
    await prefs.setInt('user_id', data['user_id']);

    return data;
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_id');
  }
}