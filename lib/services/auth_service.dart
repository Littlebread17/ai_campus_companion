import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/signup_validation.dart';
import 'notification_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<DocumentSnapshot<Map<String, dynamic>>> profileChanges(String uid) =>
      _firestore.collection('users').doc(uid).snapshots();

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

      final userRef = _firestore.collection('users').doc(user.uid);
      final existingProfile = await userRef.get();

      // Existing profiles are grandfathered so current demo and admin accounts
      // keep working. The auth wrapper holds new users on email verification.
      if (!user.emailVerified && !existingProfile.exists) {
        return null;
      }

      final profileReady = existingProfile.exists
          ? true
          : await _ensureSchoolProfile(user);
      if (!profileReady) {
        await _auth.signOut();
        return 'Your student profile could not be completed. '
            'Please register again or contact support.';
      }

      try {
        await NotificationService().saveCurrentToken();
      } catch (_) {
        // Push token saving should not block a valid login.
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

  Future<String?> resendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Please log in again.';
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser?.emailVerified == true) {
        return 'Your email is already verified. Continue to the dashboard.';
      }
      await refreshedUser?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return '${e.code}: ${e.message}';
    } catch (e) {
      return 'Unable to resend the verification email: $e';
    }
  }

  Future<String?> completeEmailVerification() async {
    try {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user == null) return 'Please log in again.';
      if (!user.emailVerified) {
        return 'Email is not verified yet. Open the link in your email first.';
      }

      // Refresh the token so Firestore sees email_verified immediately.
      await user.getIdToken(true);
      final profileReady = await _ensureSchoolProfile(user);
      return profileReady
          ? null
          : 'Your verified student profile could not be completed.';
    } on FirebaseAuthException catch (e) {
      return '${e.code}: ${e.message}';
    } on FirebaseException catch (e) {
      return '${e.code}: ${e.message}';
    } catch (e) {
      return 'Unable to check email verification: $e';
    }
  }

  Future<bool> _ensureSchoolProfile(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    if (userDoc.exists) return true;

    final email = (user.email ?? '').trim().toLowerCase();
    if (email.isEmpty || !user.emailVerified) return false;

    final pendingRef = _firestore.collection('pendingProfiles').doc(user.uid);
    final pendingDoc = await pendingRef.get();
    final pending = pendingDoc.data();

    if (pendingDoc.exists && pending != null) {
      final studentId = normalizeStudentId('${pending['studentId'] ?? ''}');
      final intakeYear = pending['intakeYear'];
      final validPendingProfile =
          isValidStudentEmail(email, studentId) &&
          intakeYear is int &&
          isValidIntakeYear(intakeYear, DateTime.now().year);
      if (!validPendingProfile) return false;

      final batch = _firestore.batch();
      batch.set(userRef, {
        'name': '${pending['name'] ?? user.displayName ?? studentId}'.trim(),
        'email': email,
        'studentId': studentId,
        'programme': '${pending['programme'] ?? ''}'.trim(),
        'year': '$intakeYear',
        'intakeYear': intakeYear,
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'source': 'verified-signup',
      });
      batch.delete(pendingRef);
      await batch.commit();
      return true;
    }

    // Legacy fallback for accounts prepared before verified self-signup.
    final registryRef = _firestore.collection('studentRegistry');
    final uidRegistry = await registryRef.doc(user.uid).get();
    final emailRegistry = uidRegistry.exists
        ? uidRegistry
        : await registryRef.doc(email).get();
    final registryData = emailRegistry.data();
    if (!emailRegistry.exists || registryData == null) return false;

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
    required int intakeYear,
  }) async {
    final cleanName = name.trim();
    final cleanStudentId = normalizeStudentId(studentId);
    final cleanEmail = email.trim().toLowerCase();
    final cleanProgramme = programme.trim();
    final currentYear = DateTime.now().year;

    if (cleanName.isEmpty || cleanProgramme.isEmpty) {
      return 'Name and programme are required.';
    }
    if (!isValidStudentId(cleanStudentId)) {
      return 'Student ID must use I followed by 8 digits.';
    }
    if (!isValidStudentEmail(cleanEmail, cleanStudentId)) {
      return 'Student email must match the Student ID and end with '
          '@$studentEmailDomain.';
    }
    if (!isValidIntakeYear(intakeYear, currentYear)) {
      return 'Select an intake year from ${currentYear - 10} to $currentYear.';
    }

    User? createdUser;
    DocumentReference<Map<String, dynamic>>? pendingRef;
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      createdUser = credential.user;
      if (createdUser == null) return 'Could not create the account.';

      await createdUser.updateDisplayName(cleanName);
      pendingRef = _firestore
          .collection('pendingProfiles')
          .doc(createdUser.uid);
      await pendingRef.set({
        'name': cleanName,
        'email': cleanEmail,
        'studentId': cleanStudentId,
        'programme': cleanProgramme,
        'intakeYear': intakeYear,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await createdUser.sendEmailVerification();
      await _auth.signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      await _removeIncompleteSignup(createdUser, pendingRef);
      return '${e.code}: ${e.message}';
    } on FirebaseException catch (e) {
      await _removeIncompleteSignup(createdUser, pendingRef);
      return '${e.code}: ${e.message}';
    } catch (e) {
      await _removeIncompleteSignup(createdUser, pendingRef);
      return 'Unknown error: $e';
    }
  }

  Future<void> _removeIncompleteSignup(
    User? user,
    DocumentReference<Map<String, dynamic>>? pendingRef,
  ) async {
    try {
      await pendingRef?.delete();
    } catch (_) {}
    try {
      await user?.delete();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<void> logoutUser() async {
    await _auth.signOut();
  }
}
