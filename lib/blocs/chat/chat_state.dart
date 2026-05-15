import 'package:equatable/equatable.dart';

import '../../models/message.dart';

enum ChatStatus { initial, loading, loaded, error }

class ChatState extends Equatable {
  final ChatStatus status;
  final List<Message> messages;
  final List<Message> pendingMessages;
  final Map<String, bool> typingUsers;
  final String searchQuery;
  final bool isSearchOpen;
  final List<String> searchResults;
  final int currentSearchIndex;
  final bool isSearching;
  final bool isUploading;
  final double uploadProgress;
  final bool isOnline;
  final Message? editingMessage;
  final String? error;

  const ChatState({
    required this.status,
    this.messages = const [],
    this.pendingMessages = const [],
    this.typingUsers = const {},
    this.searchQuery = '',
    this.isSearchOpen = false,
    this.searchResults = const [],
    this.currentSearchIndex = 0,
    this.isSearching = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    this.isOnline = true,
    this.editingMessage,
    this.error,
  });

  const ChatState.initial() : this(status: ChatStatus.initial);

  List<Message> visibleMessages(String uid) {
    final all = [
      ...pendingMessages,
      ...messages,
    ].where((message) => !message.isHiddenFor(uid)).toList();
    all.sort((a, b) {
      final aTime = a.timestamp?.millisecondsSinceEpoch ?? 0;
      final bTime = b.timestamp?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return all;
  }

  String? get currentSearchMessageId {
    if (searchResults.isEmpty) {
      return null;
    }
    return searchResults[currentSearchIndex.clamp(0, searchResults.length - 1)];
  }

  ChatState copyWith({
    ChatStatus? status,
    List<Message>? messages,
    List<Message>? pendingMessages,
    Map<String, bool>? typingUsers,
    String? searchQuery,
    bool? isSearchOpen,
    List<String>? searchResults,
    int? currentSearchIndex,
    bool? isSearching,
    bool? isUploading,
    double? uploadProgress,
    bool? isOnline,
    Message? editingMessage,
    String? error,
    bool clearEditing = false,
    bool clearError = false,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      pendingMessages: pendingMessages ?? this.pendingMessages,
      typingUsers: typingUsers ?? this.typingUsers,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchOpen: isSearchOpen ?? this.isSearchOpen,
      searchResults: searchResults ?? this.searchResults,
      currentSearchIndex: currentSearchIndex ?? this.currentSearchIndex,
      isSearching: isSearching ?? this.isSearching,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      isOnline: isOnline ?? this.isOnline,
      editingMessage: clearEditing
          ? null
          : editingMessage ?? this.editingMessage,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    messages,
    pendingMessages,
    typingUsers,
    searchQuery,
    isSearchOpen,
    searchResults,
    currentSearchIndex,
    isSearching,
    isUploading,
    uploadProgress,
    isOnline,
    editingMessage,
    error,
  ];
}
