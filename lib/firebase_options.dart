import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client identifiers from the existing LivingWiki Firebase project.
/// These are not credentials. Access is enforced by Firebase Auth and rules.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS || TargetPlatform.macOS => ios,
      _ => throw UnsupportedError('Use iOS, Android, macOS, or web.'),
    };
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyBXFeKYpWMMYyH-Ck9dS4x2uPTO7tUY9RI',
    appId: '1:661893013313:web:e929cf76ab9d8d44614bc0',
    messagingSenderId: '661893013313',
    projectId: 'living-atlas-7622a',
    authDomain: 'living-atlas-7622a.firebaseapp.com',
    storageBucket: 'living-atlas-7622a.firebasestorage.app',
  );
  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyAIyfGF19z77Vgv3RAki9Nmn8SrFr2d12A',
    appId: '1:661893013313:ios:3ad658c88e3f1a71614bc0',
    messagingSenderId: '661893013313',
    projectId: 'living-atlas-7622a',
    storageBucket: 'living-atlas-7622a.firebasestorage.app',
    iosBundleId: 'com.livingwiki.mobile',
    iosClientId:
        '661893013313-kkqrag20m8472hr1kltprgi0glfkthik.apps.googleusercontent.com',
  );
  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBskBawpup2IQd1VvQ1DoeLf91BGes-aV4',
    appId: '1:661893013313:android:a9ee8844e1004ad6614bc0',
    messagingSenderId: '661893013313',
    projectId: 'living-atlas-7622a',
    storageBucket: 'living-atlas-7622a.firebasestorage.app',
  );
}
