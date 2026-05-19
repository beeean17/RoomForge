import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class AuthSession {
  const AuthSession({required this.uid, this.email, this.displayName});

  final String uid;
  final String? email;
  final String? displayName;

  factory AuthSession.fromFirebaseUser(User user) {
    return AuthSession(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
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
  const FirebaseAuthRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

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

    await _firebaseAuth.signInWithPopup(provider);
  }

  @override
  Future<void> signOut() {
    return _firebaseAuth.signOut();
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
