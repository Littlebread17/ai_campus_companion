import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = credential.user;
      if (user == null) return 'Unable to sign in.';

      final profileReady = await _ensureSchoolProfile(user);
      if (!profileReady) {
        await _auth.signOut();
        return 'This account is not registered by the school. Please contact admin.';
      }

      try {
        await NotificationService().saveCurrentToken();
      } catch (_) {
        // Push token saving should not block a valid school login.
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return '${e.code}: ${e.message}';
    } on FirebaseException catch (e) {
      return '${e.code}: ${e.message}';
    } catch (e) {
      return 'Unknown error: $e';
    }
  }

  Future<bool> _ensureSchoolProfile(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    if (userDoc.exists) return true;

    final email = (user.email ?? '').trim().toLowerCase();
    if (email.isEmpty) return false;

    final registryRef = _firestore.collection('studentRegistry');
    final uidRegistry = await registryRef.doc(user.uid).get();
    Map<String, dynamic>? data;

    if (uidRegistry.exists) {
      data = uidRegistry.data();
    } else {
      final emailRegistry = await registryRef.doc(email).get();
      if (!emailRegistry.exists) return false;
      data = emailRegistry.data();
    }

    final registryData = data;
    if (registryData == null) return false;

    await userRef.set({
      'name':
          registryData['name'] ?? user.displayName ?? email.split('@').first,
      'email': email,
      'studentId': registryData['studentId'] ?? '',
      'programme': registryData['programme'] ?? '',
      'year': registryData['year'] ?? '',
      'role': registryData['role'] ?? 'student',
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'studentRegistry',
    }, SetOptions(merge: true));
    return true;
  }

  Future<String?> registerUser({
    required String name,
    required String email,
    required String password,
    required String studentId,
    required String programme,
    required String year,
  }) async {
    return 'Registration is managed by the school. Please use your school-created account.';
  }

  Future<void> logoutUser() async {
    await _auth.signOut();
  }
}
