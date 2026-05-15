import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MessageType { text, audio, image, video, deleted }

enum MessageStatus { sending, sent, delivered, seen, failed }

MessageType messageTypeFromString(String? value) {
  return MessageType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => MessageType.text,
  );
}

MessageStatus messageStatusFromString(String? value) {
  return MessageStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => MessageStatus.sent,
  );
}

class Message extends Equatable {
  final String id;
  final String senderId;
  final String senderName;
  final MessageType type;
  final String content;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? audioDuration;
  final int? videoDuration;
  final Timestamp? timestamp;
  final MessageStatus status;
  final Map<String, String> reactions;
  final bool isEdited;
  final Timestamp? editedAt;
  final bool isDeleted;
  final List<String> deletedFor;
  final bool deletedForEveryone;
  final String? replyTo;
  final String? localId;
  final double uploadProgress;

  const Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.type,
    required this.content,
    required this.status,
    required this.reactions,
    required this.isEdited,
    required this.isDeleted,
    required this.deletedFor,
    required this.deletedForEveryone,
    this.mediaUrl,
    this.thumbnailUrl,
    this.audioDuration,
    this.videoDuration,
    this.timestamp,
    this.editedAt,
    this.replyTo,
    this.localId,
    this.uploadProgress = 1,
  });

  factory Message.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Message(
      id: (data['id'] ?? doc.id) as String,
      senderId: (data['senderId'] ?? '') as String,
      senderName: (data['senderName'] ?? '') as String,
      type: messageTypeFromString(data['type'] as String?),
      content: (data['content'] ?? data['text'] ?? '') as String,
      mediaUrl: data['mediaUrl'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      audioDuration: (data['audioDuration'] as num?)?.toInt(),
      videoDuration: (data['videoDuration'] as num?)?.toInt(),
      timestamp: (data['timestamp'] ?? data['createdAt']) as Timestamp?,
      status: messageStatusFromString(data['status'] as String?),
      reactions: Map<String, String>.from((data['reactions'] as Map?) ?? {}),
      isEdited: (data['isEdited'] ?? false) as bool,
      editedAt: data['editedAt'] as Timestamp?,
      isDeleted: (data['isDeleted'] ?? false) as bool,
      deletedFor: List<String>.from((data['deletedFor'] as List?) ?? []),
      deletedForEveryone: (data['deletedForEveryone'] ?? false) as bool,
      replyTo: data['replyTo'] as String?,
      localId: data['localId'] as String?,
      uploadProgress: ((data['uploadProgress'] as num?) ?? 1).toDouble(),
    );
  }

  factory Message.pending({
    required String id,
    required String senderId,
    required String senderName,
    required String content,
    required String localId,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? audioDuration,
    int? videoDuration,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      senderName: senderName,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      audioDuration: audioDuration,
      videoDuration: videoDuration,
      timestamp: Timestamp.now(),
      status: MessageStatus.sending,
      reactions: const {},
      isEdited: false,
      isDeleted: false,
      deletedFor: const [],
      deletedForEveryone: false,
      localId: localId,
      uploadProgress: 0,
    );
  }

  bool isHiddenFor(String uid) => deletedFor.contains(uid);

  bool get isMedia =>
      type == MessageType.audio ||
      type == MessageType.image ||
      type == MessageType.video;

  Message copyWith({
    MessageStatus? status,
    double? uploadProgress,
    Map<String, String>? reactions,
  }) {
    return Message(
      id: id,
      senderId: senderId,
      senderName: senderName,
      type: type,
      content: content,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      audioDuration: audioDuration,
      videoDuration: videoDuration,
      timestamp: timestamp,
      status: status ?? this.status,
      reactions: reactions ?? this.reactions,
      isEdited: isEdited,
      editedAt: editedAt,
      isDeleted: isDeleted,
      deletedFor: deletedFor,
      deletedForEveryone: deletedForEveryone,
      replyTo: replyTo,
      localId: localId,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  Map<String, dynamic> toFirestore({Object? timestampValue}) {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'type': type.name,
      'content': content,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'audioDuration': audioDuration,
      'videoDuration': videoDuration,
      'timestamp': timestampValue ?? timestamp ?? FieldValue.serverTimestamp(),
      'status': status.name,
      'reactions': reactions,
      'isEdited': isEdited,
      'editedAt': editedAt,
      'isDeleted': isDeleted,
      'deletedFor': deletedFor,
      'deletedForEveryone': deletedForEveryone,
      'replyTo': replyTo,
      'localId': localId,
      'uploadProgress': uploadProgress,
    };
  }

  @override
  List<Object?> get props => [
    id,
    senderId,
    senderName,
    type,
    content,
    mediaUrl,
    thumbnailUrl,
    audioDuration,
    videoDuration,
    timestamp,
    status,
    reactions,
    isEdited,
    editedAt,
    isDeleted,
    deletedFor,
    deletedForEveryone,
    replyTo,
    localId,
    uploadProgress,
  ];
}
