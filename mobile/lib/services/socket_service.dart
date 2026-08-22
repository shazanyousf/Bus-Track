import 'dart:async';
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'notification_service.dart';

/// Singleton that manages one Socket.io connection for the whole app.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;
  Future<void> Function(Map<String, dynamic>)? _onSessionRevoked;
  bool _connecting = false;

  void setSessionRevokedHandler(Future<void> Function(Map<String, dynamic>) handler) {
    _onSessionRevoked = handler;
  }

  String get socketUrl {
    final envUrl = dotenv.env['SOCKET_URL'];
    if (envUrl != null && envUrl.isNotEmpty) {
      return _resolveLocalHost(envUrl);
    }
    return _defaultSocketUrl();
  }

  String _defaultSocketUrl() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'http://localhost:3000';
      default:
        return 'http://127.0.0.1:3000';
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

  /// Call once when the app starts or the user logs in.
  void connect({String? token}) {
    if (_socket != null && (_socket!.connected || _connecting)) return;

    final socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth(token == null ? {} : {'token': token})
          .disableAutoConnect()
          .build(),
    );
    _socket = socket;
    _connecting = true;

    socket.connect();

    socket.onConnect((_) {
      _connecting = false;
      print('✅ Socket connected');
      final session = _sessionFromToken(token);
      print('[SESSION LOGIN] userId=${session['userId']} sessionId=${session['sessionId']} socketId=${socket.id}');
    });
    socket.onDisconnect((_) {
      _connecting = false;
      print('❌ Socket disconnected socketId=${socket.id}');
    });
    socket.onError((e) => print('Socket error: $e'));
    socket.on('session:revoked', (data) async {
      final event = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      print('[SESSION REVOKE RECEIVED] eventUserId=${event['userId']} eventSessionId=${event['sessionId']}');
      await _onSessionRevoked?.call(event);
    });
  }

  Map<String, dynamic> _sessionFromToken(String? token) {
    if (token == null) return {};
    try {
      final parts = token.split('.');
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return {
        'userId': payload['id'],
        'sessionId': payload['sessionId'],
      };
    } catch (_) {
      return {};
    }
  }

  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 10)}) async {
    final deadline = DateTime.now().add(timeout);
    while (!(_socket?.connected ?? false) && DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    return _socket?.connected ?? false;
  }

  /// Driver calls this to broadcast their GPS location.
  void emitLocation({
    required String busId,
    required String tripId,
    required double latitude,
    required double longitude,
    required double speed,
  }) {
    if (!(_socket?.connected ?? false)) {
      print('DRIVER LOCATION SKIPPED: socket is not connected');
      return;
    }
    print('[DRIVER SOCKET EMIT] event=driver:location busId=$busId tripId=$tripId latitude=$latitude longitude=$longitude');
    _socket!.emit('driver:location', {
      'busId': busId,
      'tripId': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
      'speed': speed,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> emitTripStarted({required String busId, required String tripId}) async {
    if (!(_socket?.connected ?? false)) {
      print('TRIP START SKIPPED: socket is not connected');
      return null;
    }
    final completer = Completer<Map<String, dynamic>?>();
    _socket!.emitWithAck(
      'driver:trip:start',
      {'busId': busId, 'tripId': tripId},
      ack: (data) {
        if (!completer.isCompleted) {
          completer.complete(data is Map ? Map<String, dynamic>.from(data) : null);
        }
      },
    );
    return completer.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
  }

  void emitTripCompleted({required String busId, required String tripId}) {
    _socket?.emit('driver:trip:complete', {'busId': busId, 'tripId': tripId});
  }

  void listenToTripStarted(void Function(Map<String, dynamic>) onUpdate) {
    _socket?.on('trip:started', (data) {
      if (data is Map) onUpdate(Map<String, dynamic>.from(data));
    });
  }

  void listenToTripCompleted(void Function(Map<String, dynamic>) onUpdate) {
    _socket?.on('trip:completed', (data) {
      if (data is Map) onUpdate(Map<String, dynamic>.from(data));
    });
  }

  void stopListeningToTripEvents() {
    _socket?.off('trip:started');
    _socket?.off('trip:completed');
  }

  /// Parent calls this to listen to a specific bus.
  void listenToBus(String busId, void Function(Map<String, dynamic>) onData) {
    _socket?.on('bus:location:$busId', (data) {
      if (data is Map) {
        onData(Map<String, dynamic>.from(data));
      }
    });
    _socket?.on('trip:location', (data) {
      if (data is Map && data['busId']?.toString() == busId) {
        onData(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Parent listens for bus alerts (traffic jam / accidents) from driver.
  void listenToBusAlerts(String busId, void Function(Map<String, dynamic>) onAlert) {
    _socket?.on('bus:alert:$busId', (data) {
      if (data is Map) {
        final alert = Map<String, dynamic>.from(data);
        onAlert(alert);
        NotificationService.instance.show(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: 'BusTrack bus alert',
          body: alert['message']?.toString() ?? 'A bus alert was received.',
        );
      }
    });
  }

  /// Driver sends an alert message to parents on this bus.
  void emitAlert({
    required String busId,
    required String message,
    String type = 'traffic',
  }) {
    _socket?.emit('driver:alert', {
      'busId': busId,
      'message': message,
      'type': type,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Request the current known position for a bus from the server.
  Future<bool> requestBusLocation(String busId) async {
    final connected = await waitForConnection();
    if (!connected) return false;
    _socket!.emit('bus:request', busId);
    return true;
  }
  void listenToProfileUpdates(void Function(Map<String, dynamic>) onUpdate) {
    _socket?.on('profile:updated', (data) {
      if (data is Map) onUpdate(Map<String, dynamic>.from(data));
    });
  }
  void stopListeningToProfileUpdates() {
    _socket?.off('profile:updated');
  }

  void listenToRegistrationUpdates(
      void Function(Map<String, dynamic>) onUpdate) {
    _socket?.on('registration:updated', (data) {
      if (data is Map) onUpdate(Map<String, dynamic>.from(data));
    });
  }

  void stopListeningToRegistrationUpdates() {
    _socket?.off('registration:updated');
  }

  void listenToPaymentReceived(void Function(Map<String, dynamic>) onUpdate) {
    _socket?.on('payment:received', (data) {
      if (data is Map) onUpdate(Map<String, dynamic>.from(data));
    });
  }

  void stopListeningToPaymentReceived() {
    _socket?.off('payment:received');
  }

  /// Stop listening to a bus (call when leaving the tracking screen).
  void stopListening(String busId) {
    _socket?.off('bus:location:$busId');
  }

  void stopListeningAlerts(String busId) {
    _socket?.off('bus:alert:$busId');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
    _connecting = false;
  }
}
