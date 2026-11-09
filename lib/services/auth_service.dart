import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  // Keep one service instance and one auth-state stream for the whole app.
  static final AuthService instance = AuthService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late final Stream<User?> authStateChanges = _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> changePassword(
    String newPassword, {
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to change your password.');
    }

    final email = user.email;
    if (email == null || email.isEmpty) {
      throw StateError('No email address is available for reauthentication.');
    }
    if (currentPassword.isEmpty) {
      throw StateError('Enter your current password to verify your identity.');
    }

    // Always verify the current password so the field is meaningful,
    // even when Firebase considers the session recent enough to update.
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    Future<void> reauthenticate() async {
      try {
        await user.reauthenticateWithCredential(credential);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'wrong-password' ||
            error.code == 'invalid-credential') {
          throw StateError('Your current password is incorrect.');
        }
        rethrow;
      }
    }

    await reauthenticate();
    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'requires-recent-login') rethrow;
      // Firebase still wants fresh credentials: reauthenticate and retry.
      await reauthenticate();
      await user.updatePassword(newPassword);
    }
  }
}

String authErrorMessage(Object error) {
  if (error is StateError) return error.message.toString();
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'The password is too weak for this Firebase project.';
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'operation-not-allowed':
        return 'Enable Email/Password sign-in in Firebase Console.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'requires-recent-login':
        return 'Please sign in again and retry this action.';
      case 'user-mismatch':
        return 'The credentials do not match the signed-in account.';
      default:
        return 'Authentication failed (${error.code}). Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
