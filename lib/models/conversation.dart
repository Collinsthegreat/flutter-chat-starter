import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantAvatars;
  final String lastMessage;
  final Timestamp? lastMessageTime;
  final Map<String, int> unreadCount;
  final Timestamp? createdAt;

  Conversation({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.participantAvatars,
    required this.lastMessage,
    required this.unreadCount,
    this.lastMessageTime,
    this.createdAt,
  });

  factory Conversation.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final rawUnread = Map<String, dynamic>.from(
      (data['unreadCount'] as Map?) ?? {},
    );

    return Conversation(
      id: doc.id,
      participants: List<String>.from((data['participants'] as List?) ?? []),
      participantNames: Map<String, String>.from(
        (data['participantNames'] as Map?) ?? {},
      ),
      participantAvatars: Map<String, String>.from(
        (data['participantAvatars'] as Map?) ?? {},
      ),
      lastMessage: (data['lastMessage'] ?? '') as String,
      lastMessageTime:
          (data['lastMessageTime'] ?? data['lastMessageAt']) as Timestamp?,
      unreadCount: rawUnread.map(
        (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
      ),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  String displayNameFor(String uid) {
    final other = participants.where((id) => id != uid).toList();
    if (other.isEmpty) {
      return 'Saved messages';
    }
    return other.map((id) => participantNames[id] ?? 'Unknown user').join(', ');
  }

  String? avatarFor(String uid) {
    final other = participants.where((id) => id != uid).toList();
    if (other.isEmpty) {
      return participantAvatars[uid];
    }
    return participantAvatars[other.first];
  }
}
