import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const Duration _timeout = Duration(seconds: 20);
  
  static String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL'];
    if (envUrl != null && envUrl.isNotEmpty) return _resolveLocalHost(envUrl);
    return _defaultBaseUrl();
  }

  static String _defaultBaseUrl() {
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

  static String _resolveLocalHost(String url) {
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

  static Future<Map> getActiveTrip(String busId, String token) async {
    final res = await http.get(Uri.parse('$baseUrl/buses/$busId/active-trip'), headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('No active trip');
  }

  static Future<List> getActiveTrips(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/buses/active-trips'), headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load active trips');
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

  // ── Users (admin) ──────────────────────────────────────
  static Future<List> getUsers(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/users'), headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load users');
  }

  static Future<Map> updateUser(String token, String id, Map data) async {
    final res = await http.put(Uri.parse('$baseUrl/users/$id'), headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> deleteUser(String token, String id) async {
    final res = await http.delete(Uri.parse('$baseUrl/users/$id'), headers: headers(token)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  // Current user (self)
  static Future<Map> getCurrentUser(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/users/me'), headers: headers(token)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> updateCurrentUser(String token, Map data) async {
    final res = await http.put(Uri.parse('$baseUrl/users/me'), headers: headers(token), body: jsonEncode(data)).timeout(_timeout);
    return jsonDecode(res.body);
  }

  static Future<Map> deleteCurrentUser(String token) async {
    final res = await http.delete(Uri.parse('$baseUrl/users/me'), headers: headers(token)).timeout(_timeout);
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

  static Future<Map<String, dynamic>> getAdminDashboardStats(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/dashboard/stats'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(res.body));
    throw Exception('Failed to load dashboard statistics');
  }

  static Future<Uint8List> downloadRegistrationReport(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/reports/registrations.xlsx'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Failed to download registration report');
  }

  static Future<Uint8List> downloadRegistrationReportCsv(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/reports/registrations.csv'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Failed to download registration report');
  }

  static Future<Uint8List> downloadPaymentReport(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/reports/payments.xlsx'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Failed to download payment report');
  }

  static Future<Uint8List> downloadPaymentReportCsv(String token) async {
    final res = await http.get(Uri.parse('$baseUrl/reports/payments.csv'),
        headers: headers(token)).timeout(_timeout);
    if (res.statusCode == 200) return res.bodyBytes;
    throw Exception('Failed to download payment report');
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

  static Future<Map> payRegistration(String token, String id) async {
    final res = await http.post(Uri.parse('$baseUrl/registrations/$id/payment/order'),
        headers: headers(token)).timeout(_timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to complete payment');
    }
    return body;
  }

  static Future<Map> verifyRegistrationPayment(String token, String id, {
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    final res = await http.post(Uri.parse('$baseUrl/registrations/$id/payment/verify'),
        headers: headers(token), body: jsonEncode({
          'razorpay_payment_id': paymentId,
          'razorpay_order_id': orderId,
          'razorpay_signature': signature,
        })).timeout(_timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Payment verification failed');
    }
    return body;
  }

  static Future<Map> assignRegistration(String token, String id, String busId,
      {String? routeId}) async {
    final res = await http.put(Uri.parse('$baseUrl/registrations/$id/assignment'),
        headers: headers(token), body: jsonEncode({'busId': busId, 'routeId': routeId})).timeout(_timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to assign bus');
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

  // ── Notices ──────────────────────────────────────────────
  static Future<List> getNotices(String token, {bool includeExpired = false}) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/notices?includeExpired=$includeExpired'),
          headers: headers(token),
        )
        .timeout(_timeout);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Failed to load notices');
  }

  static Future<Map> createNotice(
    String token, {
    required String title,
    required String message,
    required String audience,
    required String priority,
    String attachmentUrl = '',
    String? expiresAt,
    File? attachmentFile,
    List<int>? attachmentBytes,
    String? attachmentName,
  }) async {
    final uri = Uri.parse('$baseUrl/notices');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..fields['title'] = title
      ..fields['message'] = message
      ..fields['audience'] = audience
      ..fields['priority'] = priority;

    if (attachmentUrl.trim().isNotEmpty) {
      req.fields['attachmentUrl'] = attachmentUrl.trim();
    }
    if (expiresAt != null && expiresAt.trim().isNotEmpty) {
      req.fields['expiresAt'] = expiresAt;
    }
    if (attachmentFile != null) {
      req.files.add(await http.MultipartFile.fromPath(
        'attachment',
        attachmentFile.path,
      ));
    } else if (attachmentBytes != null && attachmentBytes.isNotEmpty) {
      req.files.add(http.MultipartFile.fromBytes(
        'attachment',
        attachmentBytes,
        filename: attachmentName ?? 'attachment.bin',
      ));
    }

    final streamed = await req.send().timeout(_timeout);
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body);
    if (res.statusCode != 201) {
      throw Exception(body['message'] ?? 'Failed to create notice');
    }
    return body;
  }

  static Future<Map> deleteNotice(String token, String id) async {
    final res = await http
        .delete(
          Uri.parse('$baseUrl/notices/$id'),
          headers: headers(token),
        )
        .timeout(_timeout);
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['message'] ?? 'Failed to delete notice');
    }
    return body;
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
