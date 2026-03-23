import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Singleton that manages one Socket.io connection for the whole app.
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  IO.Socket? get socket => _socket;

  String get socketUrl =>
      dotenv.env['SOCKET_URL'] ?? 'http://10.0.2.2:3000';

  /// Call once when the app starts or the user logs in.
  void connect() {
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.connect();

    _socket!.onConnect((_) => print('✅ Socket connected'));
    _socket!.onDisconnect((_) => print('❌ Socket disconnected'));
    _socket!.onError((e) => print('Socket error: $e'));
  }

  /// Driver calls this to broadcast their GPS location.
  void emitLocation({
    required String busId,
    required double latitude,
    required double longitude,
    required double speed,
  }) {
    _socket?.emit('driver:location', {
  'busId': busId,
  'lat': latitude,      // ✅ CHANGE HERE
  'lng': longitude,     // ✅ CHANGE HERE
  'speed': speed,
  'timestamp': DateTime.now().toIso8601String(),
});
  }

  /// Parent calls this to listen to a specific bus.
  void listenToBus(String busId, void Function(Map<String, dynamic>) onData) {
    _socket?.on('bus:location:$busId', (data) {
      if (data is Map) {
        onData(Map<String, dynamic>.from(data));
      }
    });
  }

  /// Stop listening to a bus (call when leaving the tracking screen).
  void stopListening(String busId) {
    _socket?.off('bus:location:$busId');
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}
