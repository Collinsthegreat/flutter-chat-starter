// Configure with --dart-define values or regenerate with flutterfire configure.
// Real Firebase config files are intentionally ignored by git.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _macosAppId = String.fromEnvironment('FIREBASE_MACOS_APP_ID');

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _projectId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _storageBucket.isNotEmpty &&
      (_webAppId.isNotEmpty ||
          _androidAppId.isNotEmpty ||
          _iosAppId.isNotEmpty ||
          _macosAppId.isNotEmpty);

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return _options(_webAppId);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _options(_androidAppId);
      case TargetPlatform.iOS:
        return _options(_iosAppId);
      case TargetPlatform.macOS:
        return _options(_macosAppId);
      case TargetPlatform.windows:
        return _options(_webAppId);
      case TargetPlatform.linux:
        return _options(_webAppId);
      default:
        return _options(_webAppId);
    }
  }

  static FirebaseOptions _options(String appId) {
    return FirebaseOptions(
      apiKey: _apiKey,
      appId: appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: _storageBucket,
      iosBundleId: const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
    );
  }
}
