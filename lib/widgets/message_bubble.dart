import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/message.dart';
import 'message_status_widget.dart';
import 'reactions_row.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUid,
    required this.searchQuery,
    required this.isCurrentSearchMatch,
    required this.onLongPress,
    required this.onReactionTap,
    required this.onOpenImage,
    required this.onOpenVideo,
    required this.onPlayAudio,
    required this.onToggleSpeed,
    required this.isAudioPlaying,
    required this.audioSpeed,
  });

  final Message message;
  final bool isMine;
  final String currentUid;
  final String searchQuery;
  final bool isCurrentSearchMatch;
  final VoidCallback onLongPress;
  final ValueChanged<String> onReactionTap;
  final VoidCallback onOpenImage;
  final VoidCallback onOpenVideo;
  final VoidCallback onPlayAudio;
  final VoidCallback onToggleSpeed;
  final bool isAudioPlaying;
  final double audioSpeed;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFF1C2028);
    final textColor = isMine ? Colors.white : Colors.white.withAlpha(235);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(isMine ? 16 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 16),
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Padding(
            padding: EdgeInsets.only(
              left: isMine ? 56 : 12,
              right: isMine ? 12 : 56,
              top: 4,
              bottom: 4,
            ),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: message.status == MessageStatus.failed
                        ? Colors.red.withAlpha(55)
                        : bubbleColor,
                    borderRadius: radius,
                    border: isCurrentSearchMatch
                        ? Border.all(color: Colors.amber, width: 2)
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: _buildContent(context, textColor),
                  ),
                ),
                ReactionsRow(
                  reactions: message.reactions,
                  currentUid: currentUid,
                  onTap: onReactionTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    if (message.deletedForEveryone || message.type == MessageType.deleted) {
      return const Text(
        'This message was deleted',
        style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        switch (message.type) {
          MessageType.text => _TextContent(
            text: message.content,
            color: textColor,
            query: searchQuery,
            strong: isCurrentSearchMatch,
          ),
          MessageType.image => _ImageContent(
            message: message,
            onTap: onOpenImage,
          ),
          MessageType.video => _VideoContent(
            message: message,
            onTap: onOpenVideo,
          ),
          MessageType.audio => _AudioContent(
            message: message,
            isPlaying: isAudioPlaying,
            speed: audioSpeed,
            onPlay: onPlayAudio,
            onSpeed: onToggleSpeed,
          ),
          MessageType.deleted => const SizedBox.shrink(),
        },
        if (message.uploadProgress < 1 &&
            message.status == MessageStatus.sending) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: message.uploadProgress),
        ],
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isEdited)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Text(
                  'Edited',
                  style: TextStyle(
                    color: Colors.white60,
                    fontStyle: FontStyle.italic,
                    fontSize: 11,
                  ),
                ),
              ),
            if (isMine) MessageStatusWidget(status: message.status),
          ],
        ),
      ],
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({
    required this.text,
    required this.color,
    required this.query,
    required this.strong,
  });

  final String text;
  final Color color;
  final String query;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return Text(text, style: TextStyle(color: color, fontSize: 15));
    }
    final lower = text.toLowerCase();
    final needle = trimmed.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final index = lower.indexOf(needle, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + needle.length),
          style: TextStyle(
            backgroundColor: strong ? Colors.redAccent : Colors.amber,
            color: strong ? Colors.white : Colors.black,
          ),
        ),
      );
      start = index + needle.length;
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(color: color, fontSize: 15),
        children: spans,
      ),
    ).animate().fadeIn(duration: 160.ms);
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.message, required this.onTap});

  final Message message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = message.mediaUrl ?? '';
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: min(MediaQuery.of(context).size.width * 0.65, 260),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: _isRemote(url)
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const ColoredBox(
                      color: Colors.white10,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.broken_image),
                  )
                : Image.file(File(url), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  const _VideoContent({required this.message, required this.onTap});

  final Message message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumbnail = message.thumbnailUrl ?? '';
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: min(MediaQuery.of(context).size.width * 0.65, 260),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (thumbnail.isNotEmpty && _isRemote(thumbnail))
                  CachedNetworkImage(imageUrl: thumbnail, fit: BoxFit.cover)
                else if (thumbnail.isNotEmpty)
                  Image.file(File(thumbnail), fit: BoxFit.cover)
                else
                  const ColoredBox(color: Colors.black26),
                const Center(
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.play_arrow),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        _formatDuration(message.videoDuration ?? 0),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioContent extends StatelessWidget {
  const _AudioContent({
    required this.message,
    required this.isPlaying,
    required this.speed,
    required this.onPlay,
    required this.onSpeed,
  });

  final Message message;
  final bool isPlaying;
  final double speed;
  final VoidCallback onPlay;
  final VoidCallback onSpeed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPlay,
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        ),
        SizedBox(
          width: 118,
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(22, (index) {
              final height = 8 + ((index * 17) % 22).toDouble();
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: isPlaying ? height : height * 0.55,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(_formatDuration(message.audioDuration ?? 0)),
        TextButton(
          onPressed: onSpeed,
          child: Text('${speed.toStringAsFixed(0)}x'),
        ),
      ],
    );
  }
}

void copyMessageText(String text) {
  Clipboard.setData(ClipboardData(text: text));
}

bool _isRemote(String value) {
  return value.startsWith('http://') || value.startsWith('https://');
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}
