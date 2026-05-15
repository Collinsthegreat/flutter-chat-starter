import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/auth_repository.dart';

enum AuthViewStatus { loading, authenticated, unauthenticated, submitting }

class AuthState extends Equatable {
  final AuthViewStatus status;
  final User? user;
  final String? error;

  const AuthState({required this.status, this.user, this.error});

  const AuthState.loading() : this(status: AuthViewStatus.loading);

  AuthState copyWith({
    AuthViewStatus? status,
    User? user,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [status, user?.uid, error];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository) : super(const AuthState.loading()) {
    _subscription = _repository.authStateChanges.listen((user) async {
      if (user != null) {
        await _repository.ensureUserProfile(user);
        emit(AuthState(status: AuthViewStatus.authenticated, user: user));
      } else {
        emit(const AuthState(status: AuthViewStatus.unauthenticated));
      }
    });
  }

  final AuthRepository _repository;
  late final StreamSubscription<User?> _subscription;

  Future<void> signIn(String email, String password) async {
    await _submit(() => _repository.signInWithEmail(email, password));
  }

  Future<void> signUp(String email, String password) async {
    await _submit(() => _repository.signUpWithEmail(email, password));
  }

  Future<void> signInWithGoogle() async {
    await _submit(_repository.signInWithGoogle);
  }

  Future<void> signOut() async {
    await _repository.signOut();
  }

  Future<void> _submit(Future<void> Function() action) async {
    emit(state.copyWith(status: AuthViewStatus.submitting, clearError: true));
    try {
      await action();
    } on FirebaseAuthException catch (error) {
      emit(
        state.copyWith(
          status: AuthViewStatus.unauthenticated,
          error: error.message ?? error.code,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AuthViewStatus.unauthenticated,
          error: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
