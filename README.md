# Chat App — Stage 5

## Links
- Appetize: [add after upload]
- Demo Video: [add after recording]
- GitHub: [add repository URL]

## Features Implemented
- New chat UI: debounced user search by email/display name, existing-conversation detection, creation flow, shimmer, empty, and error states.
- Typing indicator: Firebase Realtime Database typing state with disconnect cleanup and animated dots.
- Emoji reactions: long-press quick reactions, full emoji picker, Firestore transaction updates, grouped reaction row, and real-time snapshots.
- Audio messages: microphone permission flow, hold-to-record UI, waveform-style recording feedback, Firebase Storage upload, playback with one active audio at a time, and speed toggle.
- Image/video messages: image picker, mandatory compression helpers, video duration guard, thumbnail generation, Storage upload progress, cached previews, and fullscreen viewers.
- Read receipts: sent, delivered, seen, sending, and failed statuses with real-time Firestore updates and animated icons.
- In-chat search: animated search app bar, debounced local search, match counters, result navigation, and highlighted message text.
- Edit/delete: own-message action menu, edit mode, Edited label, delete for me, delete for everyone within 24 hours, and WhatsApp-style deleted message placeholder.
- Offline send queue: Hive-backed text/media queue with connectivity detection, immediate local sending state, ordered replay, retry counts, and failed state support.

## Architecture
- Flutter + Firebase
- State management: BLoC/Cubit with `flutter_bloc`, `equatable`, and `bloc_concurrency`
- Firebase services: Auth, Firestore, Storage, and Realtime Database
- Feature-aware structure: `blocs/`, `models/`, `screens/`, `services/`, and `widgets/`

## Setup Instructions
1. Clone repo.
2. Create a Firebase project.
3. Enable Authentication with Email/Password and Google.
4. Enable Firestore Database in production mode.
5. Enable Firebase Storage.
6. Enable Realtime Database.
7. Add `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` locally. These files are ignored by git.
8. Run with Dart defines or regenerate `lib/firebase_options.dart`:

```powershell
C:\Users\USER\vscode_flutter\flutter\bin\flutter.bat run `
  --dart-define=FIREBASE_API_KEY=... `
  --dart-define=FIREBASE_PROJECT_ID=... `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... `
  --dart-define=FIREBASE_STORAGE_BUCKET=... `
  --dart-define=FIREBASE_ANDROID_APP_ID=... `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=...
```

9. Run `flutter pub get`.
10. Run `flutter run`.

## Firebase Collections
### `users/{uid}`
```json
{
  "uid": "string",
  "email": "string",
  "emailLower": "string",
  "displayName": "string",
  "displayNameLower": "string",
  "photoURL": "string",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### `conversations/{conversationId}`
```json
{
  "participants": ["uidA", "uidB"],
  "participantNames": {"uidA": "Name", "uidB": "Name"},
  "participantAvatars": {"uidA": "url", "uidB": "url"},
  "createdAt": "timestamp",
  "lastMessage": "string",
  "lastMessageTime": "timestamp",
  "unreadCount": {"uidA": 0, "uidB": 0}
}
```

### `conversations/{conversationId}/messages/{messageId}`
```json
{
  "id": "uuid",
  "senderId": "uid",
  "senderName": "string",
  "type": "text|audio|image|video|deleted",
  "content": "string",
  "mediaUrl": "string|null",
  "thumbnailUrl": "string|null",
  "audioDuration": "number|null",
  "videoDuration": "number|null",
  "timestamp": "timestamp",
  "status": "sending|sent|delivered|seen|failed",
  "reactions": {"uid": "emoji"},
  "isEdited": false,
  "editedAt": "timestamp|null",
  "isDeleted": false,
  "deletedFor": ["uid"],
  "deletedForEveryone": false,
  "replyTo": "messageId|null",
  "localId": "uuid|null"
}
```

### Realtime Database
```json
{
  "typing": {
    "conversationId": {
      "uid": {
        "isTyping": true,
        "timestamp": 1710000000000
      }
    }
  }
}
```

## Technical Decisions
- RTDB is used for typing indicators because it is low-latency and fits ephemeral presence-like state.
- Firestore snapshots power conversations, messages, reactions, edits, deletes, and receipts.
- Hive stores offline queued messages so sends survive app restarts.
- Media is compressed on-device before upload to reduce storage and bandwidth cost.
- Firebase config is read through `--dart-define`; real config files stay out of git.

## Challenges
- The starter project was intentionally minimal, so production features required adding models, services, BLoC state, platform permissions, and robust UI states while preserving the original app shell.
- Firebase project creation, real OAuth credentials, Appetize upload, social post, and two-device demo recording require the owner’s accounts and cannot be completed from this local coding session.

## Demo
- Typing indicator: record Device A typing and Device B receiving animated dots.
- Reactions: long-press a message and verify instant grouped reaction sync.
- Audio: hold to record, send, play on the second device, and toggle 2x.
- Media: send compressed image/video and open fullscreen.
- Edit/delete/search/offline: demonstrate the required Stage 5 flow in the final 2-device video.
