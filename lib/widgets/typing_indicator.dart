import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class TypingIndicatorWidget extends StatelessWidget {
  const TypingIndicatorWidget({
    super.key,
    required this.isVisible,
    required this.name,
    this.avatarUrl,
  });

  final bool isVisible;
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: isVisible
          ? Padding(
              key: const ValueKey('typing'),
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: avatarUrl == null || avatarUrl!.isEmpty
                        ? null
                        : NetworkImage(avatarUrl!),
                    child: avatarUrl == null || avatarUrl!.isEmpty
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$name is typing',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(3, (index) {
                    return Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: const BoxDecoration(
                            color: Colors.white70,
                            shape: BoxShape.circle,
                          ),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .scaleXY(
                          begin: 0.5,
                          end: 1,
                          duration: 300.ms,
                          delay: (index * 150).ms,
                          curve: Curves.easeOut,
                        )
                        .then()
                        .scaleXY(
                          begin: 1,
                          end: 0.5,
                          duration: 300.ms,
                          curve: Curves.easeIn,
                        );
                  }),
                ],
              ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.2, end: 0),
            )
          : const SizedBox.shrink(key: ValueKey('no-typing')),
    );
  }
}
