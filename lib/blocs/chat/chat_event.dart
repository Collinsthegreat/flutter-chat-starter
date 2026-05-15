import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/message.dart';

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatStarted extends ChatEvent {
  const ChatStarted();
}

class MessagesChangedInternal extends ChatEvent {
  final List<Message> messages;

  const MessagesChangedInternal(this.messages);

  @override
  List<Object?> get props => [messages];
}

class TypingChangedInternal extends ChatEvent {
  final Map<String, bool> typingUsers;

  const TypingChangedInternal(this.typingUsers);

  @override
  List<Object?> get props => [typingUsers];
}

class OnlineChangedInternal extends ChatEvent {
  final bool isOnline;

  const OnlineChangedInternal(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}

class ChatTextChanged extends ChatEvent {
  final String text;

  const ChatTextChanged(this.text);

  @override
  List<Object?> get props => [text];
}

class SendTextMessageRequested extends ChatEvent {
  final String text;

  const SendTextMessageRequested(this.text);

  @override
  List<Object?> get props => [text];
}

class SendImageMessageRequested extends ChatEvent {
  final ImageSource source;

  const SendImageMessageRequested(this.source);

  @override
  List<Object?> get props => [source];
}

class SendVideoMessageRequested extends ChatEvent {
  const SendVideoMessageRequested();
}

class SendAudioMessageRequested extends ChatEvent {
  final String filePath;
  final int durationSeconds;

  const SendAudioMessageRequested({
    required this.filePath,
    required this.durationSeconds,
  });

  @override
  List<Object?> get props => [filePath, durationSeconds];
}

class ReactToMessageRequested extends ChatEvent {
  final String messageId;
  final String emoji;

  const ReactToMessageRequested({required this.messageId, required this.emoji});

  @override
  List<Object?> get props => [messageId, emoji];
}

class BeginEditMessageRequested extends ChatEvent {
  final Message message;

  const BeginEditMessageRequested(this.message);

  @override
  List<Object?> get props => [message];
}

class CancelEditMessageRequested extends ChatEvent {
  const CancelEditMessageRequested();
}

class EditMessageRequested extends ChatEvent {
  final String messageId;
  final String content;

  const EditMessageRequested({required this.messageId, required this.content});

  @override
  List<Object?> get props => [messageId, content];
}

class DeleteMessageRequested extends ChatEvent {
  final String messageId;
  final bool forEveryone;

  const DeleteMessageRequested({
    required this.messageId,
    required this.forEveryone,
  });

  @override
  List<Object?> get props => [messageId, forEveryone];
}

class SearchMessagesEvent extends ChatEvent {
  final String query;

  const SearchMessagesEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class OpenSearchEvent extends ChatEvent {
  const OpenSearchEvent();
}

class ClearSearchEvent extends ChatEvent {
  const ClearSearchEvent();
}

class UploadProgressChangedInternal extends ChatEvent {
  final double progress;

  const UploadProgressChangedInternal(this.progress);

  @override
  List<Object?> get props => [progress];
}

class NextSearchResultRequested extends ChatEvent {
  const NextSearchResultRequested();
}

class PreviousSearchResultRequested extends ChatEvent {
  const PreviousSearchResultRequested();
}

class MarkMessagesAsSeenEvent extends ChatEvent {
  const MarkMessagesAsSeenEvent();
}

class RetryQueuedMediaEvent extends ChatEvent {
  final File file;
  final MessageType type;

  const RetryQueuedMediaEvent({required this.file, required this.type});

  @override
  List<Object?> get props => [file.path, type];
}
