import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/app_user.dart';
import '../../services/chat_repository.dart';

enum NewChatStatus { idle, loading, loaded, empty, error, opening }

class NewChatState extends Equatable {
  final NewChatStatus status;
  final String query;
  final List<AppUser> users;
  final String? error;
  final String? conversationId;

  const NewChatState({
    required this.status,
    this.query = '',
    this.users = const [],
    this.error,
    this.conversationId,
  });

  const NewChatState.initial() : this(status: NewChatStatus.idle);

  NewChatState copyWith({
    NewChatStatus? status,
    String? query,
    List<AppUser>? users,
    String? error,
    String? conversationId,
    bool clearConversation = false,
  }) {
    return NewChatState(
      status: status ?? this.status,
      query: query ?? this.query,
      users: users ?? this.users,
      error: error,
      conversationId: clearConversation
          ? null
          : conversationId ?? this.conversationId,
    );
  }

  @override
  List<Object?> get props => [status, query, users, error, conversationId];
}

class NewChatCubit extends Cubit<NewChatState> {
  NewChatCubit(this._repository, this._currentUid)
    : super(const NewChatState.initial());

  final ChatRepository _repository;
  final String _currentUid;
  Timer? _debounce;

  void queryChanged(String query) {
    _debounce?.cancel();
    emit(
      state.copyWith(
        status: query.trim().isEmpty
            ? NewChatStatus.idle
            : NewChatStatus.loading,
        query: query,
        users: const [],
        error: null,
        clearConversation: true,
      ),
    );
    if (query.trim().isEmpty) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      await search(query);
    });
  }

  Future<void> search(String query) async {
    emit(state.copyWith(status: NewChatStatus.loading, error: null));
    try {
      final users = await _repository.searchUsers(query, _currentUid);
      emit(
        state.copyWith(
          status: users.isEmpty ? NewChatStatus.empty : NewChatStatus.loaded,
          users: users,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(status: NewChatStatus.error, error: error.toString()),
      );
    }
  }

  Future<void> openConversation(AppUser user) async {
    emit(state.copyWith(status: NewChatStatus.opening, error: null));
    try {
      final id = await _repository.getOrCreateConversation(user);
      emit(state.copyWith(status: NewChatStatus.loaded, conversationId: id));
    } catch (error) {
      emit(
        state.copyWith(status: NewChatStatus.error, error: error.toString()),
      );
    }
  }

  void clearNavigation() {
    emit(state.copyWith(clearConversation: true));
  }

  @override
  Future<void> close() async {
    _debounce?.cancel();
    return super.close();
  }
}
