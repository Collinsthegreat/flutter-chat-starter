import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../blocs/audio/audio_cubit.dart';
import '../blocs/auth/auth_cubit.dart';
import '../blocs/chat/chat_bloc.dart';
import '../blocs/chat/chat_event.dart';
import '../blocs/chat/chat_state.dart';
import '../models/message.dart';
import '../services/chat_repository.dart';
import '../services/media_service.dart';
import '../services/offline_queue_service.dart';
import '../services/typing_service.dart';
import '../widgets/emoji_reaction_picker.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/ui_states.dart';
import 'media_viewer_page.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String? conversationTitle;
  final String? avatarUrl;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.conversationTitle,
    this.avatarUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textController = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _itemKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ChatBloc(
            conversationId: widget.conversationId,
            repository: context.read<ChatRepository>(),
            typingService: context.read<TypingService>(),
            offlineQueue: context.read<OfflineQueueService>(),
            mediaService: context.read<MediaService>(),
          )..add(const ChatStarted()),
        ),
        BlocProvider(create: (_) => AudioCubit()),
      ],
      child: Builder(
        builder: (context) {
          return BlocListener<ChatBloc, ChatState>(
            listenWhen: (previous, current) =>
                previous.editingMessage?.id != current.editingMessage?.id ||
                previous.currentSearchMessageId !=
                    current.currentSearchMessageId ||
                previous.error != current.error,
            listener: (context, state) {
              if (state.editingMessage != null) {
                _textController.text = state.editingMessage!.content;
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _textController.text.length),
                );
              }
              if (state.editingMessage == null &&
                  _textController.text == state.editingMessage?.content) {
                _textController.clear();
              }
              if (state.currentSearchMessageId != null) {
                _scrollToMessage(state.currentSearchMessageId!);
              }
              if (state.error != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.error!)));
              }
            },
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                return Scaffold(
                  appBar: state.isSearchOpen
                      ? _SearchAppBar(
                          controller: _searchController,
                          state: state,
                          onChanged: (query) => context.read<ChatBloc>().add(
                            SearchMessagesEvent(query),
                          ),
                          onClose: () {
                            _searchController.clear();
                            context.read<ChatBloc>().add(
                              const ClearSearchEvent(),
                            );
                            _scrollToBottom();
                          },
                          onNext: () => context.read<ChatBloc>().add(
                            const NextSearchResultRequested(),
                          ),
                          onPrevious: () => context.read<ChatBloc>().add(
                            const PreviousSearchResultRequested(),
                          ),
                        )
                      : AppBar(
                          titleSpacing: 0,
                          title: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage:
                                    widget.avatarUrl == null ||
                                        widget.avatarUrl!.isEmpty
                                    ? null
                                    : CachedNetworkImageProvider(
                                        widget.avatarUrl!,
                                      ),
                                child:
                                    widget.avatarUrl == null ||
                                        widget.avatarUrl!.isEmpty
                                    ? const Icon(Icons.person_outline)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget.conversationTitle ??
                                      widget.conversationId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            IconButton(
                              tooltip: 'Search',
                              icon: const Icon(Icons.search),
                              onPressed: () => context.read<ChatBloc>().add(
                                const OpenSearchEvent(),
                              ),
                            ),
                          ],
                        ),
                  body: _ChatBody(
                    state: state,
                    textController: _textController,
                    scrollController: _scrollController,
                    itemKeys: _itemKeys,
                    conversationTitle: widget.conversationTitle ?? 'Someone',
                    avatarUrl: widget.avatarUrl,
                    onScrollBottom: _scrollToBottom,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final context = _itemKeys[messageId]?.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.45,
      );
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({
    required this.state,
    required this.textController,
    required this.scrollController,
    required this.itemKeys,
    required this.conversationTitle,
    required this.avatarUrl,
    required this.onScrollBottom,
  });

  final ChatState state;
  final TextEditingController textController;
  final ScrollController scrollController;
  final Map<String, GlobalKey> itemKeys;
  final String conversationTitle;
  final String? avatarUrl;
  final VoidCallback onScrollBottom;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthCubit>().state.user?.uid ?? '';
    final messages = state.visibleMessages(uid);
    return Column(
      children: [
        if (!state.isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.amber.withAlpha(40),
            child: const Text('Waiting for connection...'),
          ),
        Expanded(
          child: switch (state.status) {
            ChatStatus.loading || ChatStatus.initial => const MessageShimmer(),
            ChatStatus.error => ErrorStateView(
              message: 'Failed to load messages',
              onRetry: () => context.read<ChatBloc>().add(const ChatStarted()),
            ),
            ChatStatus.loaded when messages.isEmpty => const EmptyState(
              icon: Icons.waving_hand_outlined,
              title: 'Say hello!',
            ),
            ChatStatus.loaded => BlocBuilder<AudioCubit, AudioState>(
              builder: (context, audioState) {
                return NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels < 160) {
                      context.read<ChatBloc>().add(
                        const MarkMessagesAsSeenEvent(),
                      );
                    }
                    return false;
                  },
                  child: ListView.builder(
                    controller: scrollController,
                    reverse: true,
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final key = itemKeys.putIfAbsent(
                        message.id,
                        GlobalKey.new,
                      );
                      final isMine = message.senderId == uid;
                      return KeyedSubtree(
                        key: key,
                        child: MessageBubble(
                          message: message,
                          isMine: isMine,
                          currentUid: uid,
                          searchQuery: state.searchQuery,
                          isCurrentSearchMatch:
                              state.currentSearchMessageId == message.id,
                          onLongPress: () =>
                              _showMessageActions(context, message, isMine),
                          onReactionTap: (emoji) =>
                              context.read<ChatBloc>().add(
                                ReactToMessageRequested(
                                  messageId: message.id,
                                  emoji: emoji,
                                ),
                              ),
                          onOpenImage: () => _openImage(context, message),
                          onOpenVideo: () => _openVideo(context, message),
                          onPlayAudio: () => context.read<AudioCubit>().play(
                            messageId: message.id,
                            url: message.mediaUrl ?? '',
                          ),
                          onToggleSpeed: () =>
                              context.read<AudioCubit>().changeSpeed(),
                          isAudioPlaying:
                              audioState.playingMessageId == message.id &&
                              audioState.status == AudioStatus.playing,
                          audioSpeed: audioState.speed,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          },
        ),
        TypingIndicatorWidget(
          isVisible: state.typingUsers.values.any((isTyping) => isTyping),
          name: conversationTitle,
          avatarUrl: avatarUrl,
        ),
        _InputBar(controller: textController, onScrollBottom: onScrollBottom),
      ],
    );
  }

  void _showMessageActions(BuildContext context, Message message, bool isMine) {
    if (!isMine) {
      showEmojiReactionPicker(
        context: context,
        onSelected: (emoji) => context.read<ChatBloc>().add(
          ReactToMessageRequested(messageId: message.id, emoji: emoji),
        ),
      );
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161A21),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              children: [
                if (message.type == MessageType.text)
                  ListTile(
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('Edit'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.read<ChatBloc>().add(
                        BeginEditMessageRequested(message),
                      );
                    },
                  ),
                if (message.type == MessageType.text)
                  ListTile(
                    leading: const Icon(Icons.copy_outlined),
                    title: const Text('Copy'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      Clipboard.setData(ClipboardData(text: message.content));
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.add_reaction_outlined),
                  title: const Text('React'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    showEmojiReactionPicker(
                      context: context,
                      onSelected: (emoji) => context.read<ChatBloc>().add(
                        ReactToMessageRequested(
                          messageId: message.id,
                          emoji: emoji,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete(context, message);
                  },
                ),
              ],
            ),
          ),
        ).animate().slideY(begin: 0.2, end: 0);
      },
    );
  }

  void _confirmDelete(BuildContext context, Message message) {
    final sentAt = message.timestamp?.toDate();
    final canDeleteForEveryone =
        sentAt == null || DateTime.now().difference(sentAt).inHours < 24;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161A21),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_remove_outlined),
                  title: const Text('Delete for me'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.read<ChatBloc>().add(
                      DeleteMessageRequested(
                        messageId: message.id,
                        forEveryone: false,
                      ),
                    );
                  },
                ),
                if (canDeleteForEveryone)
                  ListTile(
                    leading: const Icon(Icons.delete_forever_outlined),
                    title: const Text('Delete for everyone'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      context.read<ChatBloc>().add(
                        DeleteMessageRequested(
                          messageId: message.id,
                          forEveryone: true,
                        ),
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.close),
                  title: const Text('Cancel'),
                  onTap: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openImage(BuildContext context, Message message) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) {
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => ImageViewerPage(url: url)));
  }

  void _openVideo(BuildContext context, Message message) {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) {
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => VideoViewerPage(url: url)));
  }
}

class _SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SearchAppBar({
    required this.controller,
    required this.state,
    required this.onChanged,
    required this.onClose,
    required this.onNext,
    required this.onPrevious,
  });

  final TextEditingController controller;
  final ChatState state;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  Size get preferredSize => const Size.fromHeight(104);

  @override
  Widget build(BuildContext context) {
    final hasQuery = state.searchQuery.trim().isNotEmpty;
    final counter = state.searchResults.isEmpty
        ? hasQuery
              ? '0 of 0'
              : ''
        : '${state.currentSearchIndex + 1} of ${state.searchResults.length}';
    return AppBar(
      automaticallyImplyLeading: false,
      title: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search messages...',
          prefixIcon: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onClose,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
          ),
          border: InputBorder.none,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              if (state.isSearching)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(counter),
              const Spacer(),
              IconButton(
                tooltip: 'Previous',
                onPressed: state.searchResults.isEmpty ? null : onPrevious,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: state.searchResults.isEmpty ? null : onNext,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.15, end: 0);
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onScrollBottom});

  final TextEditingController controller;
  final VoidCallback onScrollBottom;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, chatState) {
          return BlocBuilder<AudioCubit, AudioState>(
            builder: (context, audioState) {
              final editing = chatState.editingMessage;
              return DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFF111318),
                  border: Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (editing != null)
                      _EditingHeader(
                        message: editing,
                        onCancel: () {
                          controller.clear();
                          context.read<ChatBloc>().add(
                            const CancelEditMessageRequested(),
                          );
                        },
                      ),
                    if (audioState.status == AudioStatus.recording)
                      _RecordingBar(audioState: audioState)
                    else if (audioState.status == AudioStatus.preview)
                      _AudioPreviewBar(controller: controller)
                    else
                      _ComposerRow(
                        controller: controller,
                        onScrollBottom: onScrollBottom,
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ComposerRow extends StatelessWidget {
  const _ComposerRow({required this.controller, required this.onScrollBottom});

  final TextEditingController controller;
  final VoidCallback onScrollBottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Attach',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAttachmentSheet(context),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              onChanged: (text) =>
                  context.read<ChatBloc>().add(ChatTextChanged(text)),
              decoration: InputDecoration(
                hintText: 'Type a message',
                filled: true,
                fillColor: const Color(0xFF1C2028),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onLongPressStart: (_) =>
                context.read<AudioCubit>().startRecording(),
            onLongPressMoveUpdate: (details) {
              if (details.offsetFromOrigin.dx < -100) {
                context.read<AudioCubit>().cancelRecording();
              }
            },
            onLongPressEnd: (_) async {
              final audioCubit = context.read<AudioCubit>();
              final duration = audioCubit.state.durationSeconds;
              final path = await audioCubit.stopRecording();
              if (path != null && context.mounted) {
                context.read<ChatBloc>().add(
                  SendAudioMessageRequested(
                    filePath: path,
                    durationSeconds: max(duration, 1),
                  ),
                );
                audioCubit.clearPreview();
              }
            },
            child: IconButton.filled(
              tooltip: 'Hold to record',
              onPressed: () => _showMicHint(context),
              icon: const Icon(Icons.mic),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: () {
              final text = controller.text;
              controller.clear();
              context.read<ChatBloc>().add(SendTextMessageRequested(text));
              onScrollBottom();
            },
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  void _showAttachmentSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161A21),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<ChatBloc>().add(
                    const SendImageMessageRequested(ImageSource.camera),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Photo Library'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<ChatBloc>().add(
                    const SendImageMessageRequested(ImageSource.gallery),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_outlined),
                title: const Text('Video Library'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<ChatBloc>().add(
                    const SendVideoMessageRequested(),
                  );
                },
              ),
              const ListTile(
                leading: Icon(Icons.insert_drive_file_outlined),
                title: Text('File'),
                subtitle: Text('Coming soon'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showMicHint(BuildContext context) async {
    final status = await Permission.microphone.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      if (!context.mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Microphone permission'),
          content: const Text(
            'Microphone access is needed to record audio messages.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.audioState});

  final AudioState audioState;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat())
              .fade(begin: 0.3, end: 1, duration: 600.ms),
          const SizedBox(width: 10),
          Text(_formatDuration(audioState.durationSeconds)),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: List.generate(26, (index) {
                final scale = (sin(index + audioState.amplitude * 4) + 1) / 2;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      height: 8 + (scale * 26 * audioState.amplitude),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withAlpha(190),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 16),
          const Text('Slide to cancel →'),
        ],
      ),
    );
  }
}

class _AudioPreviewBar extends StatelessWidget {
  const _AudioPreviewBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AudioCubit, AudioState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Delete audio',
                onPressed: () => context.read<AudioCubit>().discardPreview(),
                icon: const Icon(Icons.delete_outline),
              ),
              Expanded(
                child: Text(
                  'Audio preview • ${_formatDuration(state.durationSeconds)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              FilledButton.icon(
                onPressed: state.filePath == null
                    ? null
                    : () {
                        context.read<ChatBloc>().add(
                          SendAudioMessageRequested(
                            filePath: state.filePath!,
                            durationSeconds: max(state.durationSeconds, 1),
                          ),
                        );
                        context.read<AudioCubit>().clearPreview();
                      },
                icon: const Icon(Icons.send),
                label: const Text('Send'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditingHeader extends StatelessWidget {
  const _EditingHeader({required this.message, required this.onCancel});

  final Message message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      color: Colors.white.withAlpha(16),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editing message',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cancel edit',
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.2, end: 0).fadeIn();
  }
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remaining = seconds % 60;
  return '$minutes:${remaining.toString().padLeft(2, '0')}';
}
