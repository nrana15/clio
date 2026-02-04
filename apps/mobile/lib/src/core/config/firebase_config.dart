import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase configuration options
class FirebaseConfig {
  /// Android configuration
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'clio-app-12345',
    storageBucket: 'clio-app-12345.appspot.com',
  );

  /// iOS configuration
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'clio-app-12345',
    storageBucket: 'clio-app-12345.appspot.com',
    iosClientId: 'YOUR_IOS_CLIENT_ID',
    iosBundleId: 'com.clio.app',
  );

  /// Web configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_WEB_API_KEY',
    appId: 'YOUR_WEB_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'clio-app-12345',
    authDomain: 'clio-app-12345.firebaseapp.com',
    storageBucket: 'clio-app-12345.appspot.com',
    measurementId: 'YOUR_MEASUREMENT_ID',
  );

  /// Get platform-specific options
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    
    switch (Platform.operatingSystem) {
      case 'ios':
        return ios;
      case 'android':
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }
}
