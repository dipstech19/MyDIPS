import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
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
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDHfbByFU-dMorWCHkz_BeK7vGMZhHrzVI',
    appId: '1:581884367090:android:afa92063ebd997da35406b',
    messagingSenderId: '581884367090',
    projectId: 'dips-management',
    storageBucket: 'dips-management.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
      apiKey: "AIzaSyCKq618bn1FIz9H5BMhVX6_g0BGrrH8tV4",
      authDomain: "dips-management.firebaseapp.com",
      projectId: "dips-management",
      storageBucket: "dips-management.firebasestorage.app",
      messagingSenderId: "581884367090",
      appId: "1:581884367090:web:105605eb69c3032d35406b",
      measurementId: "G-GZY5S9Y9ZE"
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDHfbByFU-dMorWCHkz_BeK7vGMZhHrzVI',
    appId: '1:581884367090:ios:dips-management-ios',
    messagingSenderId: '581884367090',
    projectId: 'dips-management',
    storageBucket: 'dips-management.firebasestorage.app',
    iosBundleId: 'com.dipsmanagment.dipsmanagment',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDHfbByFU-dMorWCHkz_BeK7vGMZhHrzVI',
    appId: '1:581884367090:macos:dips-management-macos',
    messagingSenderId: '581884367090',
    projectId: 'dips-management',
    storageBucket: 'dips-management.firebasestorage.app',
    iosBundleId: 'com.dipsmanagment.dipsmanagment',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDHfbByFU-dMorWCHkz_BeK7vGMZhHrzVI',
    appId: '1:581884367090:web:dips-management-windows',
    messagingSenderId: '581884367090',
    projectId: 'dips-management',
    storageBucket: 'dips-management.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDHfbByFU-dMorWCHkz_BeK7vGMZhHrzVI',
    appId: '1:581884367090:web:dips-management-linux',
    messagingSenderId: '581884367090',
    projectId: 'dips-management',
    storageBucket: 'dips-management.firebasestorage.app',
  );
}
