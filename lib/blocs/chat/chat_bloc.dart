import 'dart:async';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

import '../../models/app_user.dart';
import '../../models/message.dart';
import '../../services/chat_repository.dart';
import '../../services/media_service.dart';
import '../../services/offline_queue_service.dart';
import '../../services/typing_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

EventTransformer<E> debounceRestartable<E>(Duration duration) {
  return (events, mapper) {
    return restartable<E>().call(events.debounceTime(duration), mapper);
  };
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required this.conversationId,
    required ChatRepository repository,
    required TypingService typingService,
    required OfflineQueueService offlineQueue,
    required MediaService mediaService,
  }) : _repository = repository,
       _typingService = typingService,
       _offlineQueue = offlineQueue,
       _mediaService = mediaService,
       super(const ChatState.initial()) {
    on<ChatStarted>(_onStarted);
    on<MessagesChangedInternal>(_onMessagesChanged);
    on<TypingChangedInternal>(_onTypingChanged);
    on<OnlineChangedInternal>(_onOnlineChanged);
    on<ChatTextChanged>(_onTextChanged);
    on<SendTextMessageRequested>(_onSendText, transformer: sequential());
    on<SendImageMessageRequested>(_onSendImage, transformer: sequential());
    on<SendVideoMessageRequested>(_onSendVideo, transformer: sequential());
    on<SendAudioMessageRequested>(_onSendAudio, transformer: sequential());
    on<ReactToMessageRequested>(_onReact);
    on<BeginEditMessageRequested>(_onBeginEdit);
    on<CancelEditMessageRequested>(_onCancelEdit);
    on<EditMessageRequested>(_onEdit);
    on<DeleteMessageRequested>(_onDelete);
    on<SearchMessagesEvent>(
      _onSearch,
      transformer: debounceRestartable(const Duration(milliseconds: 400)),
    );
    on<OpenSearchEvent>(_onOpenSearch);
    on<ClearSearchEvent>(_onClearSearch);
    on<UploadProgressChangedInternal>(_onUploadProgress);
    on<NextSearchResultRequested>(_onNextSearch);
    on<PreviousSearchResultRequested>(_onPreviousSearch);
    on<MarkMessagesAsSeenEvent>(_onMarkSeen);
  }

  final String conversationId;
  final ChatRepository _repository;
  final TypingService _typingService;
  final OfflineQueueService _offlineQueue;
  final MediaService _mediaService;
  final Uuid _uuid = const Uuid();

  StreamSubscription<List<Message>>? _messagesSubscription;
  StreamSubscription<Map<String, bool>>? _typingSubscription;
  StreamSubscription<bool>? _onlineSubscription;
  Timer? _typingTimer;

  String get _uid => _repository.currentUid;

  String get _senderName {
    final user = _repository.currentFirebaseUser;
    return user == null ? 'Me' : AppUser.fromFirebase(user).displayName;
  }

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    emit(state.copyWith(status: ChatStatus.loading, clearError: true));
    await _messagesSubscription?.cancel();
    await _typingSubscription?.cancel();
    await _onlineSubscription?.cancel();

    _messagesSubscription = _repository
        .messagesFor(conversationId)
        .listen(
          (messages) => add(MessagesChangedInternal(messages)),
          onError: (Object error) => emit(
            state.copyWith(status: ChatStatus.error, error: error.toString()),
          ),
        );
    _typingSubscription = _typingService
        .getTypingStream(conversationId)
        .listen((typing) => add(TypingChangedInternal(typing)));
    _onlineSubscription = _offlineQueue.onlineChanges.listen(
      (online) => add(OnlineChangedInternal(online)),
    );

    final pending = await _pendingMessagesFromQueue();
    emit(
      state.copyWith(
        status: ChatStatus.loaded,
        pendingMessages: pending,
        isOnline: await _offlineQueue.isOnline,
      ),
    );
    await _repository.markDelivered(conversationId);
    await _flushQueueIfOnline();
  }

  void _onMessagesChanged(
    MessagesChangedInternal event,
    Emitter<ChatState> emit,
  ) {
    final deliveredLocalIds = event.messages
        .map((message) => message.localId)
        .whereType<String>()
        .toSet();
    final pending = state.pendingMessages
        .where((message) => !deliveredLocalIds.contains(message.localId))
        .toList();
    emit(
      state.copyWith(
        status: ChatStatus.loaded,
        messages: event.messages,
        pendingMessages: pending,
        clearError: true,
      ),
    );
    if (state.searchQuery.isNotEmpty) {
      add(SearchMessagesEvent(state.searchQuery));
    }
  }

  void _onTypingChanged(TypingChangedInternal event, Emitter<ChatState> emit) {
    final others = Map<String, bool>.from(event.typingUsers)..remove(_uid);
    emit(state.copyWith(typingUsers: others));
  }

  Future<void> _onOnlineChanged(
    OnlineChangedInternal event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isOnline: event.isOnline));
    if (event.isOnline) {
      await _flushQueueIfOnline();
    }
  }

  Future<void> _onTextChanged(
    ChatTextChanged event,
    Emitter<ChatState> emit,
  ) async {
    _typingTimer?.cancel();
    final text = event.text.trim();
    await _typingService.setTyping(conversationId, _uid, text.isNotEmpty);
    if (text.isNotEmpty) {
      _typingTimer = Timer(const Duration(milliseconds: 800), () {
        _typingService.setTyping(conversationId, _uid, false);
      });
    }
  }

  Future<void> _onSendText(
    SendTextMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty) {
      return;
    }
    await _typingService.setTyping(conversationId, _uid, false);

    if (state.editingMessage != null) {
      await _repository.editMessage(
        conversationId: conversationId,
        messageId: state.editingMessage!.id,
        content: text,
      );
      emit(state.copyWith(clearEditing: true));
      return;
    }

    if (await _offlineQueue.isOnline) {
      await _repository.sendTextMessage(
        conversationId: conversationId,
        content: text,
      );
      return;
    }

    final localId = _uuid.v4();
    await _offlineQueue.enqueue({
      'kind': MessageType.text.name,
      'conversationId': conversationId,
      'content': text,
      'localId': localId,
      'senderId': _uid,
      'senderName': _senderName,
    });
    emit(
      state.copyWith(
        pendingMessages: [
          Message.pending(
            id: localId,
            senderId: _uid,
            senderName: _senderName,
            content: text,
            localId: localId,
          ),
          ...state.pendingMessages,
        ],
        isOnline: false,
      ),
    );
  }

  Future<void> _onSendImage(
    SendImageMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    final media = await _mediaService.pickImage(event.source);
    if (media == null) {
      return;
    }
    await _sendMedia(emit, type: MessageType.image, file: media.file);
  }

  Future<void> _onSendVideo(
    SendVideoMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    final media = await _mediaService.pickVideo();
    if (media == null) {
      return;
    }
    await _sendMedia(
      emit,
      type: MessageType.video,
      file: media.file,
      thumbnail: media.thumbnail,
      videoDuration: media.durationSeconds,
    );
  }

  Future<void> _onSendAudio(
    SendAudioMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _sendMedia(
      emit,
      type: MessageType.audio,
      file: File(event.filePath),
      audioDuration: event.durationSeconds,
    );
  }

  Future<void> _sendMedia(
    Emitter<ChatState> emit, {
    required MessageType type,
    required File file,
    File? thumbnail,
    int? audioDuration,
    int? videoDuration,
  }) async {
    final localId = _uuid.v4();
    if (!await _offlineQueue.isOnline) {
      await _offlineQueue.enqueue({
        'kind': type.name,
        'conversationId': conversationId,
        'filePath': file.path,
        'thumbnailPath': thumbnail?.path,
        'audioDuration': audioDuration,
        'videoDuration': videoDuration,
        'localId': localId,
        'senderId': _uid,
        'senderName': _senderName,
      });
      emit(
        state.copyWith(
          pendingMessages: [
            Message.pending(
              id: localId,
              senderId: _uid,
              senderName: _senderName,
              content: '',
              localId: localId,
              type: type,
              mediaUrl: file.path,
              thumbnailUrl: thumbnail?.path,
              audioDuration: audioDuration,
              videoDuration: videoDuration,
            ),
            ...state.pendingMessages,
          ],
          isOnline: false,
        ),
      );
      return;
    }

    emit(state.copyWith(isUploading: true, uploadProgress: 0));
    try {
      await _repository.sendMediaMessage(
        conversationId: conversationId,
        type: type,
        file: file,
        thumbnail: thumbnail,
        audioDuration: audioDuration,
        videoDuration: videoDuration,
        localId: localId,
        onProgress: (progress) {
          add(UploadProgressChangedInternal(progress));
        },
      );
      emit(state.copyWith(isUploading: false, uploadProgress: 1));
    } catch (error) {
      emit(
        state.copyWith(
          isUploading: false,
          uploadProgress: 0,
          error: error.toString(),
        ),
      );
    }
  }

  Future<void> _onReact(
    ReactToMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _repository.toggleReaction(
      conversationId: conversationId,
      messageId: event.messageId,
      emoji: event.emoji,
    );
  }

  void _onBeginEdit(BeginEditMessageRequested event, Emitter<ChatState> emit) {
    emit(state.copyWith(editingMessage: event.message));
  }

  void _onCancelEdit(
    CancelEditMessageRequested event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(clearEditing: true));
  }

  Future<void> _onEdit(
    EditMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _repository.editMessage(
      conversationId: conversationId,
      messageId: event.messageId,
      content: event.content,
    );
    emit(state.copyWith(clearEditing: true));
  }

  Future<void> _onDelete(
    DeleteMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    await _repository.deleteMessage(
      conversationId: conversationId,
      messageId: event.messageId,
      forEveryone: event.forEveryone,
    );
  }

  void _onSearch(SearchMessagesEvent event, Emitter<ChatState> emit) {
    final query = event.query.trim().toLowerCase();
    if (query.isEmpty) {
      emit(
        state.copyWith(
          searchQuery: '',
          isSearchOpen: true,
          searchResults: const [],
          currentSearchIndex: 0,
          isSearching: false,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        isSearching: true,
        searchQuery: event.query,
        isSearchOpen: true,
      ),
    );
    final results = state.messages
        .where(
          (message) =>
              message.type == MessageType.text &&
              !message.deletedForEveryone &&
              message.content.toLowerCase().contains(query),
        )
        .map((message) => message.id)
        .toList();
    emit(
      state.copyWith(
        searchQuery: event.query,
        isSearchOpen: true,
        searchResults: results,
        currentSearchIndex: results.isEmpty ? 0 : 0,
        isSearching: false,
      ),
    );
  }

  void _onOpenSearch(OpenSearchEvent event, Emitter<ChatState> emit) {
    emit(state.copyWith(isSearchOpen: true));
  }

  void _onClearSearch(ClearSearchEvent event, Emitter<ChatState> emit) {
    emit(
      state.copyWith(
        searchQuery: '',
        isSearchOpen: false,
        searchResults: const [],
        currentSearchIndex: 0,
        isSearching: false,
      ),
    );
  }

  void _onUploadProgress(
    UploadProgressChangedInternal event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(uploadProgress: event.progress));
  }

  void _onNextSearch(NextSearchResultRequested event, Emitter<ChatState> emit) {
    if (state.searchResults.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        currentSearchIndex:
            (state.currentSearchIndex + 1) % state.searchResults.length,
      ),
    );
  }

  void _onPreviousSearch(
    PreviousSearchResultRequested event,
    Emitter<ChatState> emit,
  ) {
    if (state.searchResults.isEmpty) {
      return;
    }
    emit(
      state.copyWith(
        currentSearchIndex: (state.currentSearchIndex - 1) < 0
            ? state.searchResults.length - 1
            : state.currentSearchIndex - 1,
      ),
    );
  }

  Future<void> _onMarkSeen(
    MarkMessagesAsSeenEvent event,
    Emitter<ChatState> emit,
  ) async {
    await _repository.markSeen(conversationId);
  }

  Future<void> _flushQueueIfOnline() async {
    if (!await _offlineQueue.isOnline) {
      return;
    }
    final queued = await _offlineQueue.queuedForConversation(conversationId);
    for (final payload in queued) {
      final localId = payload['localId'] as String;
      final retryCount = (payload['retryCount'] as num?)?.toInt() ?? 0;
      if (retryCount >= 3) {
        continue;
      }
      try {
        final type = messageTypeFromString(payload['kind'] as String?);
        if (type == MessageType.text) {
          await _repository.sendTextMessage(
            conversationId: conversationId,
            content: (payload['content'] ?? '') as String,
            localId: localId,
          );
        } else {
          await _repository.sendMediaMessage(
            conversationId: conversationId,
            type: type,
            file: File(payload['filePath'] as String),
            thumbnail: payload['thumbnailPath'] == null
                ? null
                : File(payload['thumbnailPath'] as String),
            audioDuration: (payload['audioDuration'] as num?)?.toInt(),
            videoDuration: (payload['videoDuration'] as num?)?.toInt(),
            localId: localId,
          );
        }
        await _offlineQueue.remove(localId);
      } catch (_) {
        await _offlineQueue.incrementRetry(localId);
        await Future<void>.delayed(
          Duration(milliseconds: 250 * (retryCount + 1)),
        );
      }
    }
  }

  Future<List<Message>> _pendingMessagesFromQueue() async {
    final queued = await _offlineQueue.queuedForConversation(conversationId);
    return queued.map((payload) {
      final type = messageTypeFromString(payload['kind'] as String?);
      return Message.pending(
        id: payload['localId'] as String,
        senderId: (payload['senderId'] ?? _uid) as String,
        senderName: (payload['senderName'] ?? _senderName) as String,
        content: (payload['content'] ?? '') as String,
        localId: payload['localId'] as String,
        type: type,
        mediaUrl: payload['filePath'] as String?,
        thumbnailUrl: payload['thumbnailPath'] as String?,
        audioDuration: (payload['audioDuration'] as num?)?.toInt(),
        videoDuration: (payload['videoDuration'] as num?)?.toInt(),
      );
    }).toList();
  }

  @override
  Future<void> close() async {
    _typingTimer?.cancel();
    await _typingService.setTyping(conversationId, _uid, false);
    await _messagesSubscription?.cancel();
    await _typingSubscription?.cancel();
    await _onlineSubscription?.cancel();
    return super.close();
  }
}
