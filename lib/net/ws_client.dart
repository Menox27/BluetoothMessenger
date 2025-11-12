import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

enum WsStatus { idle, connecting, connected, reconnecting, closed }

class ChatMessage {
  ChatMessage({
    required this.type,
    required this.sender,
    required this.text,
    required this.timestamp,
  });

  final String type;
  final String sender;
  final String text;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'type': type,
        'sender': sender,
        'text': text,
        'ts': timestamp.millisecondsSinceEpoch ~/ 1000,
      };

  static ChatMessage fromJson(Map<String, dynamic> json) {
    final ts = (json['ts'] as num?) ??
        DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return ChatMessage(
      type: (json['type'] as String?) ?? 'msg',
      sender: (json['sender'] as String?) ?? 'unknown',
      text: (json['text'] as String?) ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts.toInt() * 1000),
    );
  }
}

class WsClient {
  WsClient({
    required this.endpoint,
    required this.username,
    this.backoffBase = const Duration(seconds: 2),
    this.backoffMax = const Duration(seconds: 20),
  });

  final Uri endpoint;
  final String username;
  final Duration backoffBase;
  final Duration backoffMax;

  final _messages = StreamController<ChatMessage>.broadcast();
  final _status = StreamController<WsStatus>.broadcast();

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<WsStatus> get status => _status.stream;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  Timer? _reconnectTimer;
  int _attempt = 0;
  var _disposed = false;

  Future<void> connect() async {
    if (_disposed) return;
    _status.add(_attempt == 0 ? WsStatus.connecting : WsStatus.reconnecting);
    try {
      _channel = WebSocketChannel.connect(endpoint);
      _channelSubscription = _channel!.stream.listen(
        _handleMessage,
        onDone: _scheduleReconnect,
        onError: (Object _, StackTrace __) => _scheduleReconnect(),
      );
      _status.add(WsStatus.connected);
      _attempt = 0;
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final payload = jsonEncode({
      'type': 'msg',
      'sender': username,
      'text': trimmed,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    _channel?.sink.add(payload);
  }

  void _handleMessage(dynamic event) {
    if (event is! String) return;
    try {
      final map = jsonDecode(event) as Map<String, dynamic>;
      _messages.add(ChatMessage.fromJson(map));
    } catch (_) {}
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _status.add(WsStatus.reconnecting);
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel?.sink.close();
    _channel = null;
    final delay = _computeBackoff();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, connect);
  }

  Duration _computeBackoff() {
    _attempt += 1;
    final multiplier = (1 << (_attempt - 1)).clamp(1, 32);
    final delay = Duration(seconds: backoffBase.inSeconds * multiplier);
    return delay > backoffMax ? backoffMax : delay;
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _channelSubscription?.cancel();
    await _channel?.sink.close();
    await _messages.close();
    await _status.close();
  }
}
