import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

typedef WsMessageCallback = void Function(Map<String, dynamic> data);

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  bool _shouldReconnect = true;
  String? _token;
  WsMessageCallback? _onMessage;

  void connect(String token, WsMessageCallback onMessage) {
    _token = token;
    _onMessage = onMessage;
    _shouldReconnect = true;
    _connect();
  }

  void _connect() {
    try {
      final uri = Uri.parse('${AppConfig.wsBaseUrl}/ws?token=$_token');
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _onMessage?.call(json);
          } catch (_) {}
        },
        onError: (_) => _scheduleReconnect(),
        onDone: () => _scheduleReconnect(),
        cancelOnError: false,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  void send(Map<String, dynamic> data) {
    try {
      _channel?.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
