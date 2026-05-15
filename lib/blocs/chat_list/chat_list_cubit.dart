import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/conversation.dart';
import '../../services/chat_repository.dart';

enum ChatListStatus { loading, loaded, error }

class ChatListState extends Equatable {
  final ChatListStatus status;
  final List<Conversation> conversations;
  final String? error;

  const ChatListState({
    required this.status,
    this.conversations = const [],
    this.error,
  });

  const ChatListState.loading() : this(status: ChatListStatus.loading);

  ChatListState copyWith({
    ChatListStatus? status,
    List<Conversation>? conversations,
    String? error,
  }) {
    return ChatListState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, conversations, error];
}

class ChatListCubit extends Cubit<ChatListState> {
  ChatListCubit(this._repository, this._uid)
    : super(const ChatListState.loading()) {
    watch();
  }

  final ChatRepository _repository;
  final String _uid;
  StreamSubscription<List<Conversation>>? _subscription;

  void watch() {
    emit(const ChatListState.loading());
    _subscription?.cancel();
    _subscription = _repository
        .conversationsFor(_uid)
        .listen(
          (conversations) {
            emit(
              ChatListState(
                status: ChatListStatus.loaded,
                conversations: conversations,
              ),
            );
          },
          onError: (Object error) {
            emit(
              ChatListState(
                status: ChatListStatus.error,
                error: error.toString(),
              ),
            );
          },
        );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
