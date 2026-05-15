import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mime/mime.dart';
import 'package:uuid/uuid.dart';

import '../models/app_user.dart';
import '../models/conversation.dart';
import '../models/message.dart';

typedef UploadProgress = void Function(double progress);

class ChatRepository {
  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    Uuid? uuid,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _uuid = uuid ?? const Uuid();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final Uuid _uuid;

  String get currentUid => _auth.currentUser?.uid ?? '';

  User? get currentFirebaseUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  CollectionReference<Map<String, dynamic>> messagesRef(String conversationId) {
    return _conversations.doc(conversationId).collection('messages');
  }

  Stream<List<Conversation>> conversationsFor(String uid) {
    return _conversations
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map(Conversation.fromDoc).toList();
        });
  }

  Stream<List<Message>> messagesFor(String conversationId, {int limit = 50}) {
    return messagesRef(conversationId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(Message.fromDoc).toList());
  }

  Future<AppUser?> userProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      return null;
    }
    return AppUser.fromDoc(doc);
  }

  Future<List<AppUser>> searchUsers(String query, String currentUid) async {
    final term = query.trim().toLowerCase();
    if (term.isEmpty) {
      return const [];
    }
    final users = _firestore.collection('users');
    final emailQuery = await users
        .orderBy('emailLower')
        .startAt([term])
        .endAt(['$term\uf8ff'])
        .limit(10)
        .get();
    final nameQuery = await users
        .orderBy('displayNameLower')
        .startAt([term])
        .endAt(['$term\uf8ff'])
        .limit(10)
        .get();

    final byId = <String, AppUser>{};
    for (final doc in [...emailQuery.docs, ...nameQuery.docs]) {
      if (doc.id != currentUid) {
        byId[doc.id] = AppUser.fromDoc(doc);
      }
    }
    return byId.values.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  Future<String> getOrCreateConversation(AppUser otherUser) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to start a chat.');
    }
    final existing = await _conversations
        .where('participants', arrayContains: user.uid)
        .limit(50)
        .get();

    for (final doc in existing.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] as List);
      if (participants.contains(otherUser.uid)) {
        return doc.id;
      }
    }

    final current = AppUser.fromFirebase(user);
    final doc = _conversations.doc();
    await doc.set({
      'participants': [current.uid, otherUser.uid],
      'participantNames': {
        current.uid: current.displayName,
        otherUser.uid: otherUser.displayName,
      },
      'participantAvatars': {
        current.uid: current.photoUrl,
        otherUser.uid: otherUser.photoUrl,
      },
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'unreadCount': {current.uid: 0, otherUser.uid: 0},
    });
    return doc.id;
  }

  Future<void> sendTextMessage({
    required String conversationId,
    required String content,
    String? localId,
  }) async {
    final text = content.trim();
    if (text.isEmpty) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send messages.');
    }
    final messageId = localId ?? _uuid.v4();
    final message = Message(
      id: messageId,
      senderId: user.uid,
      senderName: AppUser.fromFirebase(user).displayName,
      type: MessageType.text,
      content: text,
      timestamp: Timestamp.now(),
      status: MessageStatus.sent,
      reactions: const {},
      isEdited: false,
      isDeleted: false,
      deletedFor: const [],
      deletedForEveryone: false,
      localId: localId,
    );

    final convDoc = await _conversations.doc(conversationId).get();
    final participants = List<String>.from(convDoc.data()?['participants'] ?? []);

    final batch = _firestore.batch();
    batch.set(
      messagesRef(conversationId).doc(messageId),
      message.toFirestore(timestampValue: FieldValue.serverTimestamp()),
    );
    
    final updates = <String, dynamic>{
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    };
    for (final pId in participants) {
      if (pId != user.uid) {
        updates['unreadCount.$pId'] = FieldValue.increment(1);
      }
    }
    
    batch.update(_conversations.doc(conversationId), updates);
    await batch.commit();
  }

  Future<void> sendMediaMessage({
    required String conversationId,
    required MessageType type,
    required File file,
    File? thumbnail,
    int? audioDuration,
    int? videoDuration,
    UploadProgress? onProgress,
    String? localId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to send messages.');
    }
    final messageId = localId ?? _uuid.v4();
    final messageDoc = messagesRef(conversationId).doc(messageId);
    final placeholder = Message(
      id: messageId,
      senderId: user.uid,
      senderName: AppUser.fromFirebase(user).displayName,
      type: type,
      content: '',
      timestamp: Timestamp.now(),
      status: MessageStatus.sending,
      reactions: const {},
      isEdited: false,
      isDeleted: false,
      deletedFor: const [],
      deletedForEveryone: false,
      localId: localId,
      audioDuration: audioDuration,
      videoDuration: videoDuration,
      uploadProgress: 0,
    );
    await messageDoc.set(
      placeholder.toFirestore(timestampValue: FieldValue.serverTimestamp()),
    );

    try {
      final folder = switch (type) {
        MessageType.audio => 'audio',
        MessageType.image => 'images',
        MessageType.video => 'videos',
        _ => 'files',
      };
      final extension = switch (type) {
        MessageType.audio => 'm4a',
        MessageType.image => 'jpg',
        MessageType.video => 'mp4',
        _ => pExtension(file.path),
      };
      final mediaUrl = await _uploadFile(
        file,
        '$folder/$conversationId/$messageId.$extension',
        onProgress: (progress) async {
          onProgress?.call(progress);
          await messageDoc.update({'uploadProgress': progress});
        },
      );
      String? thumbnailUrl;
      if (thumbnail != null) {
        thumbnailUrl = await _uploadFile(
          thumbnail,
          'thumbnails/$conversationId/$messageId.jpg',
        );
      }
      await messageDoc.update({
        'mediaUrl': mediaUrl,
        'thumbnailUrl': thumbnailUrl,
        'audioDuration': audioDuration,
        'videoDuration': videoDuration,
        'status': MessageStatus.sent.name,
        'uploadProgress': 1,
      });
      final convDoc = await _conversations.doc(conversationId).get();
      final participants = List<String>.from(convDoc.data()?['participants'] ?? []);
      final updates = <String, dynamic>{
        'lastMessage': _lastMessageLabel(type),
        'lastMessageTime': FieldValue.serverTimestamp(),
      };
      for (final pId in participants) {
        if (pId != user.uid) {
          updates['unreadCount.$pId'] = FieldValue.increment(1);
        }
      }
      await _conversations.doc(conversationId).update(updates);
    } catch (error) {
      await messageDoc.update({
        'status': MessageStatus.failed.name,
        'uploadProgress': 0,
      });
      rethrow;
    }
  }

  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String emoji,
  }) async {
    final uid = currentUid;
    if (uid.isEmpty) {
      return;
    }
    final doc = messagesRef(conversationId).doc(messageId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      final data = snapshot.data() ?? {};
      final reactions = Map<String, String>.from(
        (data['reactions'] as Map?) ?? {},
      );
      if (reactions[uid] == emoji) {
        reactions.remove(uid);
      } else {
        reactions[uid] = emoji;
      }
      transaction.update(doc, {'reactions': reactions});
    });
  }

  Future<void> editMessage({
    required String conversationId,
    required String messageId,
    required String content,
  }) async {
    await messagesRef(conversationId).doc(messageId).update({
      'content': content.trim(),
      'isEdited': true,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
    required bool forEveryone,
  }) async {
    final uid = currentUid;
    if (forEveryone) {
      await messagesRef(conversationId).doc(messageId).update({
        'deletedForEveryone': true,
        'content': '',
        'type': MessageType.deleted.name,
      });
    } else {
      await messagesRef(conversationId).doc(messageId).update({
        'deletedFor': FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> markDelivered(String conversationId) async {
    await _markStatus(
      conversationId: conversationId,
      allowedStatuses: {MessageStatus.sent.name},
      nextStatus: MessageStatus.delivered,
    );
  }

  Future<void> markSeen(String conversationId) async {
    final uid = currentUid;
    if (uid.isNotEmpty) {
      await _conversations.doc(conversationId).update({
        'unreadCount.$uid': 0,
      });
    }
    await _markStatus(
      conversationId: conversationId,
      allowedStatuses: {MessageStatus.sent.name, MessageStatus.delivered.name},
      nextStatus: MessageStatus.seen,
    );
  }

  Future<void> _markStatus({
    required String conversationId,
    required Set<String> allowedStatuses,
    required MessageStatus nextStatus,
  }) async {
    final uid = currentUid;
    if (uid.isEmpty) {
      return;
    }
    final snapshot = await messagesRef(
      conversationId,
    ).orderBy('timestamp', descending: true).limit(100).get();
    final batch = _firestore.batch();
    var changed = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data['senderId'] != uid &&
          allowedStatuses.contains(data['status'] as String?)) {
        batch.update(doc.reference, {'status': nextStatus.name});
        changed++;
      }
    }
    if (changed > 0) {
      await batch.commit();
    }
  }

  Future<String> _uploadFile(
    File file,
    String storagePath, {
    UploadProgress? onProgress,
  }) async {
    final contentType = lookupMimeType(file.path);
    final ref = _storage.ref(storagePath);
    final task = ref.putFile(file, SettableMetadata(contentType: contentType));
    final sub = task.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total > 0) {
        onProgress?.call(snapshot.bytesTransferred / total);
      }
    });
    final result = await task;
    await sub.cancel();
    return result.ref.getDownloadURL();
  }

  String _lastMessageLabel(MessageType type) {
    return switch (type) {
      MessageType.audio => 'Audio message',
      MessageType.image => 'Photo',
      MessageType.video => 'Video',
      MessageType.deleted => 'Message deleted',
      MessageType.text => 'Message',
    };
  }

  String pExtension(String path) {
    final index = path.lastIndexOf('.');
    return index == -1 ? 'bin' : path.substring(index + 1);
  }
}
