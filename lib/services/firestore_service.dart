import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(
    String collection, {
    String? orderBy,
    bool descending = false,
  }) {
    Query<Map<String, dynamic>> query = _db.collection(collection);
    if (orderBy != null) {
      query = query.orderBy(orderBy, descending: descending);
    }
    return query.snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamUserProfile(
    String userId,
  ) {
    return _db.collection('users').doc(userId).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUsers() {
    return _db.collection('users').orderBy('email').snapshots();
  }

  Future<void> updateUserRole(String userId, String role) async {
    await _db.collection('users').doc(userId).set({
      'role': role,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserReminders(
    String userId,
  ) {
    return _db
        .collection('reminders')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserTimetable(
    String userId,
  ) {
    return _db
        .collection('timetable')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> addTimetableEntry({
    required String userId,
    required String courseCode,
    required String courseName,
    required String day,
    required String startTime,
    required String endTime,
    required String room,
    required String lecturer,
  }) async {
    await _db.collection('timetable').add({
      'userId': userId,
      'courseCode': courseCode,
      'courseName': courseName,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'lecturer': lecturer,
      'type': 'class',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTimetableEntry({
    required String id,
    required String courseCode,
    required String courseName,
    required String day,
    required String startTime,
    required String endTime,
    required String room,
    required String lecturer,
  }) async {
    await _db.collection('timetable').doc(id).set({
      'courseCode': courseCode,
      'courseName': courseName,
      'day': day,
      'startTime': startTime,
      'endTime': endTime,
      'room': room,
      'lecturer': lecturer,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteTimetableEntry(String id) async {
    await _db.collection('timetable').doc(id).delete();
  }

  /// Saves a batch of scanned/reviewed timetable rows in one write.
  Future<void> saveTimetableBatch({
    required String userId,
    required List<Map<String, dynamic>> entries,
    bool replaceExisting = false,
  }) async {
    final batch = _db.batch();
    final col = _db.collection('timetable');

    if (replaceExisting) {
      final existing = await col.where('userId', isEqualTo: userId).get();
      for (final doc in existing.docs) {
        batch.delete(doc.reference);
      }
    }

    for (final entry in entries) {
      batch.set(col.doc(), {
        'userId': userId,
        'courseCode': entry['courseCode'] ?? '',
        'courseName': entry['courseName'] ?? '',
        'day': entry['day'] ?? '',
        'startTime': entry['startTime'] ?? '',
        'endTime': entry['endTime'] ?? '',
        'room': entry['room'] ?? '',
        'lecturer': entry['lecturer'] ?? '',
        'type': 'class',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ---- Personal calendar events (one-off items the student adds) ----

  Stream<QuerySnapshot<Map<String, dynamic>>> streamUserCalendarEvents(
    String userId,
  ) {
    return _db
        .collection('calendarEvents')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Future<void> addCalendarEvent({
    required String userId,
    required String title,
    required String date,
    required String startTime,
    required String endTime,
    required String location,
    required String type,
    String courseCode = '',
    String notes = '',
  }) async {
    await _db.collection('calendarEvents').add({
      'userId': userId,
      'title': title,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'type': type,
      'courseCode': courseCode,
      'notes': notes,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCalendarEvent({
    required String id,
    required String title,
    required String date,
    required String startTime,
    required String endTime,
    required String location,
    required String type,
    String courseCode = '',
    String notes = '',
  }) async {
    await _db.collection('calendarEvents').doc(id).set({
      'title': title,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'location': location,
      'type': type,
      'courseCode': courseCode,
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteCalendarEvent(String id) async {
    await _db.collection('calendarEvents').doc(id).delete();
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
    String courseCode = '',
    String source = 'admin',
  }) async {
    await _db.collection('announcements').add({
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'targetProgramme': targetProgramme,
      'courseCode': courseCode,
      'createdBy': createdBy,
      'source': source,
      'createdAt': FieldValue.serverTimestamp(),
      'expiredAt': '',
    });
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String description,
    required String category,
    required String priority,
    required String targetProgramme,
    String courseCode = '',
  }) async {
    await _db.collection('announcements').doc(id).set({
      'title': title,
      'description': description,
      'category': category,
      'priority': priority,
      'targetProgramme': targetProgramme,
      'courseCode': courseCode,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteAnnouncement(String id) async {
    await _db.collection('announcements').doc(id).delete();
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
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateResource({
    required String id,
    required String title,
    required String description,
    required String category,
    required String courseCode,
    required String linkUrl,
  }) async {
    await _db.collection('resources').doc(id).set({
      'title': title,
      'description': description,
      'category': category,
      'courseCode': courseCode,
      'linkUrl': linkUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteResource(String id) async {
    await _db.collection('resources').doc(id).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamEventProposals({
    String? submittedBy,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('eventProposals');
    if (submittedBy != null) {
      query = query.where('submittedBy', isEqualTo: submittedBy);
    }
    return query.snapshots();
  }

  Future<void> submitEventProposal({
    required String submittedBy,
    required String studentName,
    required String title,
    required String clubName,
    required String eventDate,
    required String startTime,
    required String endTime,
    required String venue,
    required String description,
    required String contactPerson,
    required String proposalPdfUrl,
    required String proposalFileName,
  }) async {
    await _db.collection('eventProposals').add({
      'submittedBy': submittedBy,
      'studentName': studentName,
      'title': title,
      'clubName': clubName,
      'eventDate': eventDate,
      'startTime': startTime,
      'endTime': endTime,
      'venue': venue,
      'description': description,
      'contactPerson': contactPerson,
      'proposalPdfUrl': proposalPdfUrl,
      'proposalFileName': proposalFileName,
      'status': 'submitted',
      'eventAdminRemark': '',
      'mainAdminRemark': '',
      'publishedEventId': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resubmitEventProposal({
    required String proposalId,
    required String submittedBy,
    required String title,
    required String clubName,
    required String eventDate,
    required String startTime,
    required String endTime,
    required String venue,
    required String description,
    required String contactPerson,
    required String proposalPdfUrl,
    required String proposalFileName,
  }) async {
    await _db.collection('eventProposals').doc(proposalId).set({
      'submittedBy': submittedBy,
      'title': title,
      'clubName': clubName,
      'eventDate': eventDate,
      'startTime': startTime,
      'endTime': endTime,
      'venue': venue,
      'description': description,
      'contactPerson': contactPerson,
      'proposalPdfUrl': proposalPdfUrl,
      'proposalFileName': proposalFileName,
      'status': 'submitted',
      'mainAdminRemark': '',
      'resubmittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> eventAdminReviewProposal({
    required String proposalId,
    required String status,
    required String remark,
    required String reviewedBy,
  }) async {
    await _db.collection('eventProposals').doc(proposalId).set({
      'status': status,
      'eventAdminRemark': remark,
      'eventAdminReviewedBy': reviewedBy,
      'eventAdminReviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> adminRejectProposal({
    required String proposalId,
    required String remark,
    required String reviewedBy,
  }) async {
    await _db.collection('eventProposals').doc(proposalId).set({
      'status': 'admin_rejected',
      'mainAdminRemark': remark,
      'mainAdminReviewedBy': reviewedBy,
      'mainAdminReviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> publishApprovedProposal({
    required String proposalId,
    required Map<String, dynamic> proposal,
    required String approvedBy,
  }) async {
    final proposalRef = _db.collection('eventProposals').doc(proposalId);
    final eventRef = _db.collection('events').doc();
    final announcementRef = _db.collection('announcements').doc();
    final notificationRef = _db.collection('notifications').doc();

    await _db.runTransaction((transaction) async {
      final latest = await transaction.get(proposalRef);
      final latestData = latest.data();
      if (!latest.exists || latestData?['status'] != 'event_admin_checked') {
        throw StateError('Proposal is not ready to publish.');
      }

      final source = latestData ?? proposal;
      final title = (source['title'] ?? 'Approved Event').toString();
      final description = (source['description'] ?? '').toString();
      final eventDate = (source['eventDate'] ?? '').toString();
      final startTime = (source['startTime'] ?? '').toString();
      final endTime = (source['endTime'] ?? '').toString();
      final venue = (source['venue'] ?? '').toString();

      transaction.set(eventRef, {
        'title': title,
        'description': description,
        'eventDate': eventDate,
        'startTime': startTime,
        'endTime': endTime,
        'venue': venue,
        'clubName': source['clubName'] ?? '',
        'sourceProposalId': proposalId,
        'status': 'published',
        'createdBy': approvedBy,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(announcementRef, {
        'title': 'Approved Event: $title',
        'description':
            '$description\n\nVenue: $venue\nDate: $eventDate $startTime-$endTime',
        'category': 'Event',
        'priority': 'high',
        'targetProgramme': 'All',
        'createdBy': approvedBy,
        'source': 'eventProposal',
        'sourceProposalId': proposalId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiredAt': '',
      });

      transaction.set(notificationRef, {
        'title': 'New campus event: $title',
        'body': '$eventDate at $venue',
        'type': 'event',
        'audience': 'students',
        'eventId': eventRef.id,
        'sourceProposalId': proposalId,
        'createdAt': FieldValue.serverTimestamp(),
        'readBy': <String>[],
      });

      transaction.set(proposalRef, {
        'status': 'approved_published',
        'publishedEventId': eventRef.id,
        'mainAdminReviewedBy': approvedBy,
        'mainAdminReviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotifications() {
    return _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> markNotificationRead({
    required String notificationId,
    required String userId,
  }) async {
    await _db.collection('notifications').doc(notificationId).set({
      'readBy': FieldValue.arrayUnion([userId]),
    }, SetOptions(merge: true));
  }

  Future<void> addLocation({
    required String name,
    required String building,
    required String level,
    required String room,
    required String category,
    required String directionText,
    required String keywords,
    double? latitude,
    double? longitude,
  }) async {
    await _db.collection('locations').add({
      'name': name,
      'building': building,
      'level': level,
      'room': room,
      'category': category,
      'directionText': directionText,
      'keywords': keywords
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'latitude': ?latitude,
      'longitude': ?longitude,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLocation({
    required String id,
    required String name,
    required String building,
    required String level,
    required String room,
    required String category,
    required String directionText,
    required String keywords,
    double? latitude,
    double? longitude,
  }) async {
    await _db.collection('locations').doc(id).set({
      'name': name,
      'building': building,
      'level': level,
      'room': room,
      'category': category,
      'directionText': directionText,
      'keywords': keywords
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteLocation(String id) async {
    await _db.collection('locations').doc(id).delete();
  }
}
