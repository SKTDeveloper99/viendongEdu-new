import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ZkApiService {
  static const String _ipKey = 'zk_api_ip';
  static const String defaultServerUrl = 'https://faceid.phungne.io.vn';

  static Future<String> getSavedIp() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_ipKey);
    if (saved == null || saved.isEmpty) {
      return defaultServerUrl;
    }
    return saved;
  }

  static Future<void> saveIp(String ip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ipKey, ip);
  }

  static String _buildBaseUrl(String input) {
    input = input.trim();
    if (input.isEmpty) {
      input = defaultServerUrl;
    }
    if (input.startsWith('http://') || input.startsWith('https://')) {
      // Bỏ dấu slash cuối nếu có
      if (input.endsWith('/')) {
        input = input.substring(0, input.length - 1);
      }
      return input;
    }
    return 'http://$input';
  }

  static Future<List<dynamic>> getLogs(String ip) async {
    final baseUrl = _buildBaseUrl(ip);
    final uri = Uri.parse('$baseUrl/api/logs');
    final res = await http.get(uri, headers: {
      'Bypass-Tunnel-Reminder': 'true'
    }).timeout(const Duration(seconds: 10));
    
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        return body['data'] as List<dynamic>? ?? [];
      } else {
        throw Exception(body['message'] ?? 'Unknown API error');
      }
    }
    throw Exception('Không thể tải log từ thiết bị');
  }

  static Future<List<dynamic>> getUsers(String ip) async {
    final baseUrl = _buildBaseUrl(ip);
    final uri = Uri.parse('$baseUrl/api/users');
    final res = await http.get(uri, headers: {
      'Bypass-Tunnel-Reminder': 'true'
    }).timeout(const Duration(seconds: 10));
    
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        return body['data'] as List<dynamic>? ?? [];
      } else {
        throw Exception(body['message'] ?? 'Unknown API error');
      }
    }
    throw Exception('Không thể tải danh sách người dùng từ thiết bị');
  }

  static Future<List<dynamic>> getStudents(String ip) async {
    final baseUrl = _buildBaseUrl(ip);
    final uri = Uri.parse('$baseUrl/api/students');
    final res = await http.get(uri, headers: {
      'Bypass-Tunnel-Reminder': 'true'
    }).timeout(const Duration(seconds: 10));
    
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body['success'] == true) {
        return body['data'] as List<dynamic>? ?? [];
      } else {
        throw Exception(body['message'] ?? 'Unknown API error');
      }
    }
    throw Exception('Không thể tải danh sách học sinh từ CSDL');
  }
}
