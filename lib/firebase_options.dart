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
      apiKey: "AIzaSyCKq618bn1FIz9H5BMhVX6_g0BGrrH8tV4",
      authDomain: "dips-management.firebaseapp.com",
      projectId: "dips-management",
      storageBucket: "dips-management.firebasestorage.app",
      messagingSenderId: "581884367090",
      appId: "1:581884367090:web:105605eb69c3032d35406b",
      measurementId: "G-GZY5S9Y9ZE"
  );
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHfbByFU-dMorWCHkz_BeK7vGMZhHrzVI',
    appId: '1:581884367090:android:afa92063ebd997da35406b',
    messagingSenderId: '581884367090',
    projectId: 'dips-management',
    storageBucket: 'dips-management.firebasestorage.app',
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
      apiKey: "AIzaSyCKq618bn1FIz9H5BMhVX6_g0BGrrH8tV4",
      authDomain: "dips-management.firebaseapp.com",
      projectId: "dips-management",
      storageBucket: "dips-management.firebasestorage.app",
      messagingSenderId: "581884367090",
      appId: "1:581884367090:web:105605eb69c3032d35406b",
      measurementId: "G-GZY5S9Y9ZE"
  );
  static const FirebaseOptions linux = FirebaseOptions(
      apiKey: "AIzaSyCKq618bn1FIz9H5BMhVX6_g0BGrrH8tV4",
      authDomain: "dips-management.firebaseapp.com",
      projectId: "dips-management",
      storageBucket: "dips-management.firebasestorage.app",
      messagingSenderId: "581884367090",
      appId: "1:581884367090:web:105605eb69c3032d35406b",
      measurementId: "G-GZY5S9Y9ZE"
  );
}
