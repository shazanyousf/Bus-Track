import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null;
  bool get isAdmin => _user?['role'] == 'admin';
  String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return _resolveLocalHost(envUrl);
    }
    return _defaultBaseUrl();
  }

  String _defaultBaseUrl() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'http://localhost:3000/api';
      default:
        return 'http://127.0.0.1:3000/api';
    }
  }

  String _resolveLocalHost(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) return url;

    if (parsed.host != '127.0.0.1' && parsed.host != 'localhost') {
      return url;
    }

    final host = switch (defaultTargetPlatform) {
      TargetPlatform.android => '10.0.2.2',
      TargetPlatform.iOS => 'localhost',
      TargetPlatform.macOS => 'localhost',
      _ => parsed.host,
    };

    return parsed.replace(host: host).toString();
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userStr = prefs.getString('user');
    if (userStr != null) _user = jsonDecode(userStr);
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      debugPrint('Auth login URL: $url');
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Request timeout. Server not responding'),
      );
      debugPrint('Auth login response: ${res.statusCode} ${res.body}');
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', jsonEncode(_user));
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': data['message'] ?? 'Server returned ${res.statusCode}'};
    } catch (e) {
      final message = e.toString();
      debugPrint('Auth login error: $message');
      return {
        'success': false,
        'message': message.contains('timeout')
            ? 'Connection timeout. The Railway backend may be waking from sleep or not reachable at $baseUrl'
            : 'Connection error: $message',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> register(
      String name, String email, String password, String phone) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'phone': phone,
          'role': 'parent',
        }),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Request timeout'),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        _token = data['token'];
        _user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', jsonEncode(_user));
        notifyListeners();
        return {'success': true};
      }
      if (res.statusCode == 202) {
        return {'success': true, 'verificationRequired': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message']};
    } catch (e) {
      final message = e.toString();
      debugPrint('Register error: $message');
      return {
        'success': false,
        'message': message.contains('timeout')
            ? 'Connection timeout - Backend not responding at $baseUrl'
            : 'Connection error: $message',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> verifyRegistrationCode(
      String email, String verificationCode) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/verify-registration'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'verificationCode': verificationCode,
        }),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Request timeout'),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await prefs.setString('user', jsonEncode(_user));
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': data['message']};
    } catch (e) {
      final message = e.toString();
      debugPrint('Verify code error: $message');
      return {
        'success': false,
        'message': message.contains('timeout')
            ? 'Connection timeout - Backend not responding at $baseUrl'
            : 'Connection error: $message',
      };
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  /// Update locally stored user object (and persist to prefs)
  Future<void> updateLocalUser(Map<String, dynamic> user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_user));
    notifyListeners();
  }
}
