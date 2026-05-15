import 'package:firebase_database/firebase_database.dart';

class TypingService {
  TypingService({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  DatabaseReference _typingRef(String conversationId, String userId) {
    return _database.ref('typing/$conversationId/$userId');
  }

  Future<void> setTyping(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    final ref = _typingRef(conversationId, userId);
    await ref.onDisconnect().set({
      'isTyping': false,
      'timestamp': ServerValue.timestamp,
    });
    await ref.set({'isTyping': isTyping, 'timestamp': ServerValue.timestamp});
  }

  Stream<Map<String, bool>> getTypingStream(String conversationId) {
    return _database.ref('typing/$conversationId').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) {
        return <String, bool>{};
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      return value.map<String, bool>((key, raw) {
        final data = raw is Map ? raw : const {};
        final timestamp = (data['timestamp'] as num?)?.toInt() ?? 0;
        final fresh = now - timestamp < 10000;
        return MapEntry(key.toString(), (data['isTyping'] == true) && fresh);
      });
    });
  }
}
