// Firebase configuration for the SHIELD app.
//
// Hand-written from `android/app/google-services.json` (project `shield-zabnix`,
// app `1:1086152719549:android:b63fc70829f7da89da0bd4`) for Android, and from
// the "SHIELD Web" app in the same project for web (the same values
// `shield agent_invester/lib/firebase_options.dart` already uses — one Web
// app, shared across every SHIELD web build). `flutterfire configure` would
// regenerate this file and add the other platforms.
//
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for iOS — add the app in '
          'the Firebase console and run `flutterfire configure`.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for macOS — '
          'run `flutterfire configure`.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for Windows — '
          'run `flutterfire configure`.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'FirebaseOptions have not been configured for Linux — '
          'run `flutterfire configure`.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCvtCMGyaE0M2ztkvMOlEwrgrDjkulesZQ',
    appId: '1:1086152719549:android:b63fc70829f7da89da0bd4',
    messagingSenderId: '1086152719549',
    projectId: 'shield-zabnix',
    storageBucket: 'shield-zabnix.firebasestorage.app',
  );

  // SHIELD web app (project shield-zabnix) — the same "SHIELD Web" app
  // `shield agent_invester`'s web build already uses.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAjXbkhrPPgq9hwlhdKB21dG2VfvatAXTI',
    appId: '1:1086152719549:web:199b8c17ac57081cda0bd4',
    messagingSenderId: '1086152719549',
    projectId: 'shield-zabnix',
    authDomain: 'shield-zabnix.firebaseapp.com',
    storageBucket: 'shield-zabnix.firebasestorage.app',
  );
}
