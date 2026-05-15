import 'package:flutter/material.dart';

import '../models/message.dart';

class MessageStatusWidget extends StatelessWidget {
  const MessageStatusWidget({super.key, required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      MessageStatus.seen => Theme.of(context).colorScheme.primary,
      MessageStatus.failed => Colors.redAccent,
      _ => Colors.white54,
    };
    final icon = switch (status) {
      MessageStatus.sending => Icons.schedule,
      MessageStatus.sent => Icons.check,
      MessageStatus.delivered => Icons.done_all,
      MessageStatus.seen => Icons.done_all,
      MessageStatus.failed => Icons.error_outline,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Icon(icon, key: ValueKey(status), size: 15, color: color),
    );
  }
}
