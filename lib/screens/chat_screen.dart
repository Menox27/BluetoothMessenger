import 'dart:async';

import 'package:flutter/material.dart';

import '../net/ws_client.dart';
import '../widgets/chat_bubble.dart';

class ChatScreenArgs {
  const ChatScreenArgs({
    required this.ssid,
    required this.username,
    this.targetIp = '192.168.4.1',
  });

  final String ssid;
  final String username;
  final String targetIp;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.args});

  static const routeName = '/chat';

  final ChatScreenArgs args;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final WsClient _client;
  final _messages = <ChatMessage>[];
  final _controller = TextEditingController();
  late StreamSubscription<ChatMessage> _messageSub;
  late StreamSubscription<WsStatus> _statusSub;
  var _status = WsStatus.idle;

  @override
  void initState() {
    super.initState();
    final uri = Uri.parse('ws://${widget.args.targetIp}:8080/chat');
    _client = WsClient(endpoint: uri, username: widget.args.username);
    _messageSub = _client.messages.listen((message) {
      setState(() => _messages.add(message));
    });
    _statusSub = _client.status.listen((status) {
      setState(() => _status = status);
    });
    unawaited(_client.connect());
  }

  @override
  void dispose() {
    _messageSub.cancel();
    _statusSub.cancel();
    _controller.dispose();
    _client.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _client.send(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _status == WsStatus.connected;
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat · ${widget.args.ssid}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Chip(label: Text(_status.name)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final isMine = message.sender == widget.args.username;
                return ChatBubble(
                  sender: message.sender,
                  text: message.text,
                  timestamp: message.timestamp,
                  isMine: isMine,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: canSend,
                      decoration: const InputDecoration(
                        hintText: 'Nachricht',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: canSend ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
