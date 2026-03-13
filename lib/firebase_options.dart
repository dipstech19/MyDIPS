import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Stub when FlutterFire CLI has not been run. Run `flutterfire configure` to generate real values.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'stub',
    appId: 'stub',
    messagingSenderId: 'stub',
    projectId: 'stub',
    authDomain: 'stub',
    storageBucket: 'stub',
  );
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'stub',
    appId: 'stub',
    messagingSenderId: 'stub',
    projectId: 'stub',
    storageBucket: 'stub',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'stub',
    appId: 'stub',
    messagingSenderId: 'stub',
    projectId: 'stub',
    storageBucket: 'stub',
    iosBundleId: 'stub',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'stub',
    appId: 'stub',
    messagingSenderId: 'stub',
    projectId: 'stub',
    storageBucket: 'stub',
    iosBundleId: 'stub',
  );
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'stub',
    appId: 'stub',
    messagingSenderId: 'stub',
    projectId: 'stub',
    authDomain: 'stub',
    storageBucket: 'stub',
  );
  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'stub',
    appId: 'stub',
    messagingSenderId: 'stub',
    projectId: 'stub',
    authDomain: 'stub',
    storageBucket: 'stub',
  );
}
