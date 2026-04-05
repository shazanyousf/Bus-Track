import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 20);
  
  static String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    return Platform.isAndroid
        ? 'http://10.0.2.2:3000/api'
        : 'http://localhost:3000/api';
  }

  static Map<String, String> headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  // ── Buses ───────────────────────────────────────────────
  static Future<List> getBuses({String? routeId}) async {
    final query = routeId != null ? '?routeId=$routeId' : '';
    final res = await http.get(Uri.parse('$baseUrl/buses$query')).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load buses');
  }

  static Future<Map> addBus(String token, Map data) async {
    final res = await http.post(Uri.parse('$baseUrl/buses'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> updateBus(String token, String id, Map data) async {
    final res = await http.put(Uri.parse('$baseUrl/buses/$id'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> deleteBus(String token, String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/buses/$id'),
        headers: headers(token)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  // ── Routes ──────────────────────────────────────────────
  static Future<List> getRoutes() async {
    final res = await http.get(Uri.parse('$baseUrl/routes')).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load routes');
  }

  static Future<Map> addRoute(String token, Map data) async {
    final res = await http.post(Uri.parse('$baseUrl/routes'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> updateRoute(String token, String id, Map data) async {
    final res = await http.put(Uri.parse('$baseUrl/routes/$id'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> deleteRoute(String token, String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/routes/$id'),
        headers: headers(token)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  // ── Drivers ─────────────────────────────────────────────
  static Future<List> getDrivers(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/drivers'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load drivers');
  }

  static Future<Map> addDriver(String token, Map data) async {
    final res = await http.post(Uri.parse('$baseUrl/drivers'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> updateDriver(String token, String id, Map data) async {
    final res = await http.put(Uri.parse('$baseUrl/drivers/$id'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> deleteDriver(String token, String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/drivers/$id'),
        headers: headers(token)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  // ── Settings ─────────────────────────────────────────────
  static Future<Map> getSettings(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/settings'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load settings');
  }

  static Future<Map> updateSettings(String token, Map data) async {
    final res = await http.put(Uri.parse('$baseUrl/settings'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    if (res.statusCode != 200) {
      try {
        final body = jsonDecode(res.body);
        final message = body['message'] ?? 'Failed to update settings';
        throw Exception(message);
      } catch (e) {
        throw Exception('Failed to update settings (${res.statusCode}): ${res.body}');
      }
    }
    return jsonDecode(res.body);
  }

  // ── Registrations ────────────────────────────────────────
  static Future<List> getRegistrations(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/registrations'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load registrations');
  }

  static Future<Map> submitRegistration(String token, Map data) async {
    final res = await http.post(Uri.parse('$baseUrl/registrations'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 201) {
      final message = body['message'] ?? 'Failed to submit registration';
      throw Exception(message);
    }
    return body;
  }

  static Future<Map> updateRegistrationStatus(
      String token, String id, String status,
      {String remarks = ''}) async {
    final res = await http.put(
        Uri.parse('$baseUrl/registrations/$id/status'),
        headers: headers(token),
        body: jsonEncode({'status': status, 'remarks': remarks})).timeout(_timeout);

    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      final message = body['message'] ?? 'Failed to update registration status';
      throw Exception(message);
    }

    return body;
  }

  // ── Students ─────────────────────────────────────────────
  static Future<List> getStudents(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/students'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load students');
  }

  static Future<Map> addStudent(String token, Map data) async {
    final res = await http.post(Uri.parse('$baseUrl/students'),
        headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  // ── Auth ──────────────────────────────────────────────────
  static Future<Map> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    ).timeout(_timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      final message = body['message'] ?? 'Failed to request reset code';
      throw Exception(message);
    }
    return body;
  }

  static Future<Map> verifyResetCode(String email, String resetCode) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/verify-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'resetCode': resetCode}),
    ).timeout(_timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      final message = body['message'] ?? 'Invalid or expired reset code';
      throw Exception(message);
    }
    return body;
  }

  static Future<Map> resetPassword(String email, String resetCode, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'resetCode': resetCode, 'newPassword': newPassword}),
    ).timeout(_timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      final message = body['message'] ?? 'Failed to reset password';
      throw Exception(message);
    }
    return body;
  }
}
