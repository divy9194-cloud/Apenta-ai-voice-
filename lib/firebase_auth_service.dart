import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Each call returns null on success, or an error message to show.
class PentaAuth {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Stream<User?> get changes => _auth.authStateChanges();

  static Future<String?> signUp(String name, String email, String password) async {
    try {
      final UserCredential cred =
          await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user?.updateDisplayName(name.trim());
      try {
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': name.trim(),
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    }
  }

  static Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    }
  }

  static Future<String?> sendReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? e.code;
    }
  }

  static Future<void> logout() => _auth.signOut();
}
