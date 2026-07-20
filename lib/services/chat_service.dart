import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../utils/course_utils.dart';

/// Real-time chat backend. Three channel types share one `channels` collection,
/// and every channel carries a `memberIds` list so a single "arrayContains"
/// query lists everything a student belongs to:
///   * course  — the whole-class channel for a course code
///   * group   — a self-join study/project group inside a course
///   * dm      — a private 1-on-1 conversation
class ChatService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _channels =>
      _db.collection('channels');

  /// Reads the current user's display name and role once.
  Future<({String name, String role})> currentUserProfile() async {
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      final data = doc.data() ?? {};
      final email = FirebaseAuth.instance.currentUser?.email ?? 'Student';
      return (
        name: (data['name'] ?? email).toString(),
        role: (data['role'] ?? 'student').toString(),
      );
    } catch (_) {
      return (name: 'Student', role: 'student');
    }
  }

  /// All channels the user belongs to (groups, DMs, and joined course channels).
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamMyChannels() {
    return _channels
        .where('memberIds', arrayContains: _uid)
        .snapshots()
        .map((s) => s.docs);
  }

  /// Ensures the whole-class channel for [baseCode] exists and the user is a
  /// member. Safe to call repeatedly (idempotent).
  Future<void> ensureCourseChannel(
    String baseCode,
    String userName, {
    String courseName = '',
  }) async {
    final code = CourseUtils.baseCode(baseCode);
    if (code.isEmpty) return;
    final data = <String, dynamic>{
      'type': 'course',
      'courseCode': code,
      'name': 'General',
      'open': true,
      'memberIds': FieldValue.arrayUnion([_uid]),
      // Nested-map merge records each member's display name so coursemates can
      // be listed / DM'd without reading their (rule-protected) user doc.
      'memberNames': {_uid: userName},
      'createdAt': FieldValue.serverTimestamp(),
    };
    // Store the course's human name if the caller has it (from the timetable),
    // so the channel row can show "ITM3207 Software Engineering · General".
    if (courseName.isNotEmpty) data['courseName'] = courseName;
    await _channels.doc('course_$code').set(data, SetOptions(merge: true));
  }

  /// Everyone who shares at least one course channel with the current user,
  /// as {uid, name}. Names come from the channel's memberNames map.
  Future<List<({String uid, String name})>> fetchCoursemates() async {
    final snap = await _channels
        .where('memberIds', arrayContains: _uid)
        .where('type', isEqualTo: 'course')
        .get();
    final seen = <String, String>{};
    for (final doc in snap.docs) {
      final names = (doc.data()['memberNames'] as Map?) ?? {};
      names.forEach((k, v) {
        final uid = k.toString();
        if (uid != _uid && uid.isNotEmpty) {
          seen[uid] = v.toString();
        }
      });
    }
    final list = seen.entries
        .map((e) => (uid: e.key, name: e.value))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  /// Ensures the chat channel for an event exists and the user is a member.
  /// Any signed-in student may join an event chat. Returns the channel id.
  Future<String> ensureEventChannel({
    required String eventId,
    required String eventTitle,
    required String userName,
  }) async {
    final id = 'event_$eventId';
    await _channels.doc(id).set({
      'type': 'group',
      'courseCode': 'Events',
      'name': eventTitle,
      'open': true,
      'memberIds': FieldValue.arrayUnion([_uid]),
      'memberNames': {_uid: userName},
      'eventId': eventId,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return id;
  }

  /// Open groups for a course that the student can browse and join.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamGroupsForCourse(
    String baseCode,
  ) {
    return _channels
        .where('type', isEqualTo: 'group')
        .where('courseCode', isEqualTo: CourseUtils.baseCode(baseCode))
        .snapshots()
        .map((s) => s.docs);
  }

  Future<void> createGroup(String baseCode, String name) async {
    await _channels.add({
      'type': 'group',
      'courseCode': CourseUtils.baseCode(baseCode),
      'name': name,
      'open': true,
      'memberIds': [_uid],
      'createdAt': FieldValue.serverTimestamp(),
      'lastAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> joinGroup(String channelId) async {
    await _channels.doc(channelId).set({
      'memberIds': FieldValue.arrayUnion([_uid]),
    }, SetOptions(merge: true));
  }

  Future<void> leaveGroup(String channelId) async {
    await _channels.doc(channelId).set({
      'memberIds': FieldValue.arrayRemove([_uid]),
    }, SetOptions(merge: true));
  }

  /// Deterministic 1-on-1 DM channel id so both users resolve to the same doc.
  String _dmId(String otherUid) {
    final ids = [_uid, otherUid]..sort();
    return 'dm_${ids[0]}_${ids[1]}';
  }

  /// Creates (or reuses) a DM channel with another user and returns its id.
  Future<String> openDm({
    required String otherUid,
    required String otherName,
    required String myName,
  }) async {
    final id = _dmId(otherUid);
    await _channels.doc(id).set({
      'type': 'dm',
      'open': false,
      'memberIds': [_uid, otherUid],
      'names': {_uid: myName, otherUid: otherName},
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return id;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> streamMessages(
    String channelId,
  ) {
    return _channels
        .doc(channelId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs);
  }

  Future<void> sendMessage({
    required String channelId,
    required String text,
    required String senderName,
    required String senderRole,
    List<String> mentions = const [],
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final channel = _channels.doc(channelId);
    await channel.collection('messages').add({
      'senderId': _uid,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': trimmed,
      'mentions': mentions,
      'createdAt': FieldValue.serverTimestamp(),
    });
    final channelUpdate = <String, dynamic>{
      'lastMessage': trimmed,
      'lastSender': senderName,
      'lastAt': FieldValue.serverTimestamp(),
      // Sending is implicitly reading everything up to now.
      'readMarkers': {_uid: FieldValue.serverTimestamp()},
    };
    // Flag each mentioned member so their Chats tab shows an @ badge.
    if (mentions.isNotEmpty) {
      final mm = <String, dynamic>{};
      for (final uid in mentions) {
        if (uid != _uid) mm[uid] = FieldValue.serverTimestamp();
      }
      if (mm.isNotEmpty) channelUpdate['mentionMarkers'] = mm;
    }
    await channel.set(channelUpdate, SetOptions(merge: true));
  }

  /// Live channel document — carries readMarkers, typing, mentionMarkers.
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamChannelDoc(
    String channelId,
  ) {
    return _channels.doc(channelId).snapshots();
  }

  /// Mark everything in a channel read up to now, and clear any @ mention flag.
  Future<void> markChannelRead(String channelId) async {
    await _channels.doc(channelId).set({
      'readMarkers': {_uid: FieldValue.serverTimestamp()},
      'mentionMarkers': {_uid: FieldValue.delete()},
    }, SetOptions(merge: true));
  }

  /// Set/refresh this user's typing timestamp (or clear it when [typing] false).
  Future<void> setTyping(String channelId, bool typing) async {
    await _channels.doc(channelId).set({
      'typing': {
        _uid: typing ? FieldValue.serverTimestamp() : FieldValue.delete(),
      },
    }, SetOptions(merge: true));
  }

  /// Toggle the current user's [emoji] reaction on a message.
  Future<void> toggleReaction({
    required String channelId,
    required String messageId,
    required String emoji,
    required bool add,
  }) async {
    final ref =
        _channels.doc(channelId).collection('messages').doc(messageId);
    await ref.set({
      'reactions': {
        emoji: add
            ? FieldValue.arrayUnion([_uid])
            : FieldValue.arrayRemove([_uid]),
      },
    }, SetOptions(merge: true));
  }

  /// Upload image bytes to Storage and post a message that references it.
  Future<void> sendImageMessage({
    required String channelId,
    required Uint8List bytes,
    required String senderName,
    required String senderRole,
    String caption = '',
  }) async {
    final channel = _channels.doc(channelId);
    final msgRef = channel.collection('messages').doc();
    final storageRef = FirebaseStorage.instance
        .ref('chat_media/$channelId/${msgRef.id}.jpg');
    await storageRef.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await storageRef.getDownloadURL();
    await msgRef.set({
      'senderId': _uid,
      'senderName': senderName,
      'senderRole': senderRole,
      'text': caption.trim(),
      'imageUrl': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await channel.set({
      'lastMessage': caption.trim().isEmpty ? '📷 Photo' : caption.trim(),
      'lastSender': senderName,
      'lastAt': FieldValue.serverTimestamp(),
      'readMarkers': {_uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }
}
