import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<String?> registerUser({
    required String name,
    required String email,
    required String password,
    required String studentId,
    required String programme,
    required String year,
  }) async {
    try {
      print('Starting registration...');

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      print('Firebase Auth user created.');

      String uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'studentId': studentId.trim(),
        'programme': programme.trim(),
        'year': year.trim(),
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('User data saved to Firestore.');

      return null;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      return '${e.code}: ${e.message}';
    } on FirebaseException catch (e) {
      print('FirebaseException: ${e.code} - ${e.message}');
      return '${e.code}: ${e.message}';
    } catch (e) {
      print('Unknown register error: $e');
      return 'Unknown error: $e';
    }
  }

  Future<String?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('Starting login...');

      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      print('Login successful.');

      return null;
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      return '${e.code}: ${e.message}';
    } on FirebaseException catch (e) {
      print('FirebaseException: ${e.code} - ${e.message}');
      return '${e.code}: ${e.message}';
    } catch (e) {
      print('Unknown login error: $e');
      return 'Unknown error: $e';
    }
  }

  Future<void> logoutUser() async {
    await _auth.signOut();
  }
}