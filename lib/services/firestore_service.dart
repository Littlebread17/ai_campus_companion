import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String collection, {
    String? orderBy,
    bool descending = false,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(collection);
    if (orderBy != null) query = query.orderBy(orderBy, descending: descending);
    return query.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserReminders(String userId) {
    return _db.collection('reminders').where('userId', isEqualTo: userId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserTimetable(String userId) {
    return _db.collection('timetable').where('userId', isEqualTo: userId).snapshots();
  }

  Future<void> createReminder({
    required String userId,
    required String title,
    required String description,
    required String courseCode,
    required String reminderDate,
    required String reminderTime,
    String createdBy = 'user',
  }) async {
    await _db.collection('reminders').add({
      'userId': userId,
      'title': title,
      'description': description,
      'courseCode': courseCode,
      'reminderDate': reminderDate,
      'reminderTime': reminderTime,
      'status': 'active',
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addAnnouncement({
    required String title,
    required String description,
    required String category,
    required String priority,
    required String targetProgramme,
    required String createdBy,
  }) async {
    await _db.collection('announcements').add({
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'targetProgramme': targetProgramme,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'expiredAt': '',
    });
  }

  Future<void> addResource({
    required String title,
    required String description,
    required String category,
    required String courseCode,
    required String linkUrl,
    required String uploadedBy,
  }) async {
    await _db.collection('resources').add({
      'title': title,
      'description': description,
      'category': category,
      'courseCode': courseCode,
      'fileUrl': '',
      'linkUrl': linkUrl,
      'uploadedBy': uploadedBy,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
