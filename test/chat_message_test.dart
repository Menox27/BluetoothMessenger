import 'package:bluuetoothmessenger/net/ws_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ChatMessage JSON roundtrip', () {
    final now = DateTime.fromMillisecondsSinceEpoch(1731400000000);
    final message = ChatMessage(
      type: 'msg',
      sender: 'alice',
      text: 'hello',
      timestamp: now,
    );

    final json = message.toJson();
    final decoded = ChatMessage.fromJson(json);

    expect(decoded.sender, equals('alice'));
    expect(decoded.text, equals('hello'));
    expect(decoded.type, equals('msg'));
  });
}
