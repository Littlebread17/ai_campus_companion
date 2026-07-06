import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/course_utils.dart';

/// Per-student customisation for a course: nickname, custom colour, hidden
/// flag, and a "last read announcements" timestamp for unread badges.
///
/// Stored as top-level `coursePrefs` docs keyed by `{uid}_{baseCode}` so the
/// existing user-scoped security rules apply cleanly.
class CoursePref {
  final String baseCode;
  final String nickname;
  final int? colorValue;
  final bool hidden;
  final DateTime? lastReadAt;

  const CoursePref({
    required this.baseCode,
    this.nickname = '',
    this.colorValue,
    this.hidden = false,
    this.lastReadAt,
  });

  factory CoursePref.fromMap(Map<String, dynamic> data) {
    final ts = data['lastReadAt'];
    return CoursePref(
      baseCode: (data['baseCode'] ?? '').toString(),
      nickname: (data['nickname'] ?? '').toString(),
      colorValue: (data['colorValue'] as num?)?.toInt(),
      hidden: data['hidden'] == true,
      lastReadAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class CoursePrefsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _docId(String userId, String rawCode) =>
      '${userId}_${CourseUtils.baseCode(rawCode)}';

  Stream<Map<String, CoursePref>> streamPrefs(String userId) {
    return _db
        .collection('coursePrefs')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final map = <String, CoursePref>{};
      for (final doc in snap.docs) {
        final pref = CoursePref.fromMap(doc.data());
        if (pref.baseCode.isNotEmpty) map[pref.baseCode] = pref;
      }
      return map;
    });
  }

  Future<void> savePref({
    required String userId,
    required String rawCode,
    String? nickname,
    int? colorValue,
    bool? hidden,
  }) async {
    await _db.collection('coursePrefs').doc(_docId(userId, rawCode)).set({
      'userId': userId,
      'baseCode': CourseUtils.baseCode(rawCode),
      'nickname': ?nickname,
      'colorValue': ?colorValue,
      'hidden': ?hidden,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markRead({
    required String userId,
    required String rawCode,
  }) async {
    await _db.collection('coursePrefs').doc(_docId(userId, rawCode)).set({
      'userId': userId,
      'baseCode': CourseUtils.baseCode(rawCode),
      'lastReadAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
