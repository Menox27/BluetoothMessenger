import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.sender,
    required this.text,
    required this.timestamp,
    required this.isMine,
  });

  final String sender;
  final String text;
  final DateTime timestamp;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        isMine ? colorScheme.primaryContainer : colorScheme.surfaceVariant;
    final foreground =
        isMine ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final formatter = DateFormat.Hm();

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          sender,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: foreground.withOpacity(0.8)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: foreground),
              ),
              const SizedBox(height: 4),
              Text(
                formatter.format(timestamp),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: foreground.withOpacity(0.7)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
