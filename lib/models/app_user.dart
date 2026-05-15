import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String photoUrl;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.photoUrl,
  });

  factory AppUser.fromFirebase(User user) {
    final email = user.email ?? '';
    return AppUser(
      uid: user.uid,
      email: email,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : email.split('@').first,
      photoUrl: user.photoURL ?? '',
    );
  }

  factory AppUser.fromDoc(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppUser(
      uid: doc.id,
      email: (data['email'] ?? '') as String,
      displayName: (data['displayName'] ?? 'Unknown user') as String,
      photoUrl: (data['photoURL'] ?? data['photoUrl'] ?? '') as String,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'emailLower': email.toLowerCase(),
      'displayName': displayName,
      'displayNameLower': displayName.toLowerCase(),
      'photoURL': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
