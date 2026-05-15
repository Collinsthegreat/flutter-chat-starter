import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

const quickReactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '😡', '🎉', '🔥'];

Future<void> showEmojiReactionPicker({
  required BuildContext context,
  required ValueChanged<String> onSelected,
}) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss reactions',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child:
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...quickReactionEmojis.map(
                      (emoji) => InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          onSelected(emoji);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 32),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'More emojis',
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _showFullEmojiPicker(context, onSelected);
                      },
                      icon: const Icon(Icons.add_reaction_outlined),
                    ),
                  ],
                ),
              ).animate().scale(
                begin: const Offset(0, 0),
                end: const Offset(1, 1),
                curve: Curves.elasticOut,
                duration: 250.ms,
              ),
        ),
      );
    },
  );
}

void _showFullEmojiPicker(
  BuildContext context,
  ValueChanged<String> onSelected,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF111318),
    builder: (sheetContext) {
      return SizedBox(
        height: 320,
        child: EmojiPicker(
          onEmojiSelected: (_, emoji) {
            Navigator.of(sheetContext).pop();
            onSelected(emoji.emoji);
          },
          config: const Config(
            emojiViewConfig: EmojiViewConfig(
              backgroundColor: Color(0xFF111318),
            ),
            categoryViewConfig: CategoryViewConfig(
              backgroundColor: Color(0xFF111318),
              iconColorSelected: Colors.redAccent,
            ),
            bottomActionBarConfig: BottomActionBarConfig(
              backgroundColor: Color(0xFF111318),
              buttonIconColor: Colors.white70,
            ),
            searchViewConfig: SearchViewConfig(
              backgroundColor: Color(0xFF111318),
            ),
          ),
        ),
      );
    },
  );
}
