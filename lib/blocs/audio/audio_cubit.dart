import 'dart:async';
import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

enum AudioStatus { idle, recording, preview, playing, paused, error }

class AudioState extends Equatable {
  final AudioStatus status;
  final String? filePath;
  final String? playingMessageId;
  final int durationSeconds;
  final double speed;
  final String? error;

  const AudioState({
    required this.status,
    this.filePath,
    this.playingMessageId,
    this.durationSeconds = 0,
    this.speed = 1,
    this.error,
  });

  const AudioState.idle() : this(status: AudioStatus.idle);

  AudioState copyWith({
    AudioStatus? status,
    String? filePath,
    String? playingMessageId,
    int? durationSeconds,
    double? speed,
    String? error,
    bool clearFile = false,
    bool clearPlaying = false,
    bool clearError = false,
  }) {
    return AudioState(
      status: status ?? this.status,
      filePath: clearFile ? null : filePath ?? this.filePath,
      playingMessageId: clearPlaying
          ? null
          : playingMessageId ?? this.playingMessageId,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      speed: speed ?? this.speed,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    filePath,
    playingMessageId,
    durationSeconds,
    speed,
    error,
  ];
}

class AudioCubit extends Cubit<AudioState> {
  AudioCubit()
    : recorderController = RecorderController(),
      _player = AudioPlayer(),
      super(const AudioState.idle()) {
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        emit(
          state.copyWith(
            status: AudioStatus.idle,
            clearPlaying: true,
            durationSeconds: 0,
          ),
        );
      }
    });
  }

  final RecorderController recorderController;
  final AudioPlayer _player;
  final Uuid _uuid = const Uuid();
  Timer? _timer;

  Future<void> startRecording() async {
    final permission = await Permission.microphone.request();
    if (!permission.isGranted) {
      emit(
        state.copyWith(
          status: AudioStatus.error,
          error: 'Microphone permission is required to record audio.',
        ),
      );
      return;
    }

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/${_uuid.v4()}.m4a';
    
    await recorderController.record(path: path);
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(state.copyWith(durationSeconds: state.durationSeconds + 1));
    });

    emit(
      state.copyWith(
        status: AudioStatus.recording,
        filePath: path,
        durationSeconds: 0,
        clearError: true,
      ),
    );
  }

  Future<String?> stopRecording() async {
    _timer?.cancel();
    final path = await recorderController.stop();
    if (path == null || !File(path).existsSync()) {
      emit(
        state.copyWith(
          status: AudioStatus.error,
          error: 'Recording failed. Please try again.',
        ),
      );
      return null;
    }
    emit(state.copyWith(status: AudioStatus.preview, filePath: path));
    return path;
  }

  Future<void> cancelRecording() async {
    _timer?.cancel();
    await recorderController.stop();
    final path = state.filePath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    emit(const AudioState.idle());
  }

  Future<void> discardPreview() async {
    final path = state.filePath;
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    emit(const AudioState.idle());
  }

  void clearPreview() {
    emit(const AudioState.idle());
  }

  Future<void> play({required String messageId, required String url}) async {
    if (state.playingMessageId == messageId &&
        state.status == AudioStatus.playing) {
      await _player.pause();
      emit(state.copyWith(status: AudioStatus.paused));
      return;
    }
    await _player.stop();
    await _player.setUrl(url);
    await _player.setSpeed(state.speed);
    await _player.play();
    emit(
      state.copyWith(
        status: AudioStatus.playing,
        playingMessageId: messageId,
        clearError: true,
      ),
    );
  }

  Future<void> changeSpeed() async {
    final next = state.speed == 1 ? 2.0 : 1.0;
    await _player.setSpeed(next);
    emit(state.copyWith(speed: next));
  }

  @override
  Future<void> close() async {
    _timer?.cancel();
    recorderController.dispose();
    await _player.dispose();
    return super.close();
  }
}
