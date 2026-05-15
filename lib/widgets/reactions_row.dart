import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ReactionsRow extends StatelessWidget {
  const ReactionsRow({
    super.key,
    required this.reactions,
    required this.currentUid,
    required this.onTap,
  });

  final Map<String, String> reactions;
  final String currentUid;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final grouped = <String, List<String>>{};
    for (final entry in reactions.entries) {
      grouped.putIfAbsent(entry.value, () => []).add(entry.key);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: grouped.entries.map((entry) {
          final reactedByMe = entry.value.contains(currentUid);
          return Tooltip(
            message: entry.value.join(', '),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onTap(entry.key),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child:
                    Container(
                      key: ValueKey('${entry.key}-${entry.value.length}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: reactedByMe
                            ? Theme.of(
                                context,
                              ).colorScheme.primary.withAlpha(60)
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '${entry.key} ${entry.value.length}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ).animate().scale(
                      begin: const Offset(0.9, 0.9),
                      end: const Offset(1, 1),
                      duration: 160.ms,
                    ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
