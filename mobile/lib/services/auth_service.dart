import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';

enum AuthState { loading, authenticated, unauthenticated }

class AuthService extends ChangeNotifier {
  AuthService({this.onSessionRevoked}) {
    SocketService().setSessionRevokedHandler(_handleSessionRevoked);
  }

  final Future<void> Function()? onSessionRevoked;
  String? _token;
  String? _sessionId;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  AuthState _authState = AuthState.loading;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String? get currentUserId => _user?['id']?.toString() ?? _user?['_id']?.toString();
  String? get currentSessionId {
    if (_sessionId != null) return _sessionId;
    if (_token == null) return null;
    try {
      final parts = _token!.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload['sessionId']?.toString();
    } catch (_) {
      return null;
    }
  }
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null;
  bool get isAdmin => _user?['role'] == 'admin';
  bool get isDriver => _user?['role'] == 'driver';
  AuthState get authState => _authState;
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
    _authState = AuthState.loading;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _sessionId = prefs.getString('sessionId');
    final userStr = prefs.getString('user');
    if (userStr != null) _user = jsonDecode(userStr);
    final storedRole = prefs.getString('role');
    if (_user != null && storedRole != null) _user!['role'] = storedRole;
    if (_token == null || _user == null || !_isValidJwt(_token!)) {
      await _clearSession(prefs, disconnectSocket: false);
      _authState = AuthState.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      final response = await http.get(Uri.parse('$baseUrl/users/me'), headers: {
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 401) {
        await _clearSession(prefs, disconnectSocket: true);
        _token = null;
        _user = null;
        _authState = AuthState.unauthenticated;
        notifyListeners();
        return;
      }
      if (response.statusCode == 200) {
        final currentUser = jsonDecode(response.body);
        if (currentUser is Map && currentUser['role'] != null) {
          _user?['role'] = currentUser['role'];
        }
      }
    } catch (_) {
      // Keep the cached session when the backend is temporarily unavailable.
    }
    SocketService().connect(token: _token);
    _authState = AuthState.authenticated;
    notifyListeners();
  }

  bool _isValidJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final expiry = payload['exp'];
      return expiry is! num || DateTime.now().millisecondsSinceEpoch ~/ 1000 < expiry;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', _token!);
    await prefs.setString('sessionId', _sessionId ?? currentSessionId ?? '');
    await prefs.setString('user', jsonEncode(_user));
    await prefs.setString('role', _user?['role']?.toString() ?? '');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    debugPrint('[AUTH NEW SESSION CODE ACTIVE]');
    _isLoading = true;
    notifyListeners();
    try {
      SocketService().disconnect();
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
        SocketService().disconnect();
        _token = data['token'];
        _sessionId = data['sessionId']?.toString() ?? _sessionIdFromToken(_token!);
        _user = data['user'];
        debugPrint('[SESSION LOGIN] userId=$currentUserId sessionId=$currentSessionId socketId=pending');
        debugPrint('[AUTH LOGIN SUCCESS] userId=$currentUserId role=${_user?['role']} sessionId=$currentSessionId');
        await _persistSession();
        SocketService().connect(token: _token);
        _authState = AuthState.authenticated;
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
        _sessionId = data['sessionId']?.toString() ?? _sessionIdFromToken(_token!);
        _user = data['user'];
        await _persistSession();
        _authState = AuthState.authenticated;
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
        _sessionId = data['sessionId']?.toString() ?? _sessionIdFromToken(_token!);
        _user = data['user'];
        await _persistSession();
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
    final token = _token;
    if (token != null) {
      try {
        await http.post(Uri.parse('$baseUrl/auth/logout'), headers: {
          'Authorization': 'Bearer $token',
        }).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Local credentials are still cleared when the backend is unavailable.
      }
    }
    _token = null;
    _sessionId = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await _clearSession(prefs);
    _authState = AuthState.unauthenticated;
    notifyListeners();
  }

  Future<void> _handleSessionRevoked(Map<String, dynamic> event) async {
    final revokedUserId = event['userId']?.toString();
    final revokedSessionId = event['sessionId']?.toString();
    final matches = revokedUserId != null && revokedSessionId != null &&
        revokedUserId == currentUserId && revokedSessionId == currentSessionId;
    debugPrint('[SESSION REVOKE RECEIVED] eventUserId=$revokedUserId eventSessionId=$revokedSessionId currentUserId=$currentUserId currentSessionId=$currentSessionId');
    debugPrint('[SESSION REVOKE MATCH] $matches');
    if (!matches) {
      debugPrint('[SESSION REVOKE IGNORED] Event does not match current session');
      return;
    }
    debugPrint('[SESSION LOGOUT START]');
    final prefs = await SharedPreferences.getInstance();
    if (revokedUserId != currentUserId || revokedSessionId != currentSessionId) {
      debugPrint('[SESSION REVOKE IGNORED] Current session changed while processing event');
      return;
    }
    _token = null;
    _sessionId = null;
    _user = null;
    await _clearSession(prefs, disconnectSocket: true);
    _authState = AuthState.unauthenticated;
    notifyListeners();
    debugPrint('[SESSION LOGOUT COMPLETE]');
    await onSessionRevoked?.call();
  }

  Future<void> _clearSession(SharedPreferences prefs, {bool disconnectSocket = true}) async {
    await prefs.remove('token');
    await prefs.remove('sessionId');
    await prefs.remove('user');
    await prefs.remove('role');
    if (disconnectSocket) SocketService().disconnect();
  }

  String? _sessionIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload['sessionId']?.toString();
    } catch (_) {
      return null;
    }
  }

  /// Update locally stored user object (and persist to prefs)
  Future<void> updateLocalUser(Map<String, dynamic> user) async {
    _user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(_user));
    await prefs.setString('role', _user?['role']?.toString() ?? '');
    notifyListeners();
  }
}
