import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthSession {
  const AuthSession({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  factory AuthSession.fromFirebaseUser(User user) {
    return AuthSession(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}

abstract class AuthRepository {
  Stream<AuthSession?> authStateChanges();

  Future<String?> idToken();

  Future<void> signInWithGoogle();

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._firebaseAuth, {GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  static const _googleClientId = String.fromEnvironment(
    'ROOMFORGE_GOOGLE_CLIENT_ID',
  );
  static const _googleServerClientId = String.fromEnvironment(
    'ROOMFORGE_GOOGLE_SERVER_CLIENT_ID',
  );

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  Future<void>? _googleSignInInitialization;

  @override
  Stream<AuthSession?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) {
        return null;
      }
      return AuthSession.fromFirebaseUser(user);
    });
  }

  @override
  Future<String?> idToken() {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      return Future.value();
    }
    return user.getIdToken();
  }

  @override
  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile');

    if (kIsWeb) {
      await _firebaseAuth.signInWithPopup(provider);
      return;
    }

    await _initializeGoogleSignIn();
    if (!_googleSignIn.supportsAuthenticate()) {
      throw const AuthUnavailableException(
        'Native Google sign-in is unavailable on this platform.',
      );
    }

    final googleUser = await _googleSignIn.authenticate(
      scopeHint: const <String>['email', 'profile'],
    );
    final googleAuth = googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthUnavailableException(
        'Google sign-in did not return an ID token.',
      );
    }

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (kIsWeb) {
      return;
    }

    try {
      await _initializeGoogleSignIn();
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint('Google sign-out failed after Firebase sign-out: $error');
    }
  }

  Future<void> _initializeGoogleSignIn() {
    _googleSignInInitialization ??= _googleSignIn.initialize(
      clientId: _googleClientId.isEmpty ? null : _googleClientId,
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
    );
    return _googleSignInInitialization!;
  }
}

class DisabledAuthRepository implements AuthRepository {
  final StreamController<AuthSession?> _controller =
      StreamController<AuthSession?>.broadcast();

  @override
  Stream<AuthSession?> authStateChanges() {
    scheduleMicrotask(() => _controller.add(null));
    return _controller.stream;
  }

  @override
  Future<String?> idToken() async {
    return null;
  }

  @override
  Future<void> signInWithGoogle() {
    throw const AuthUnavailableException(
      'Google sign-in is unavailable until Firebase configuration is provided.',
    );
  }

  @override
  Future<void> signOut() async {
    _controller.add(null);
  }
}

class AuthUnavailableException implements Exception {
  const AuthUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}
