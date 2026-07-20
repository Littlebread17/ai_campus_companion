import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String channelId;
  final String title;
  final String subtitle;

  const ChatScreen({
    super.key,
    required this.channelId,
    required this.title,
    this.subtitle = '',
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chat = ChatService();
  final _input = TextEditingController();
  final _scroll = ScrollController();

  String _myName = 'Student';
  String _myRole = 'student';
  bool _sending = false;

  static const _reactionEmojis = ['👍', '❤️', '😂', '🎉', '❓'];

  /// uid -> display name for members (for @mention picker + highlight).
  Map<String, String> _members = {};
  String _typingText = '';
  StreamSubscription? _channelSub;

  DateTime _lastTypingPing = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _typingClear;
  bool _showMentions = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _chat.currentUserProfile().then((p) {
      if (!mounted) return;
      setState(() {
        _myName = p.name;
        _myRole = p.role;
      });
    });
    _chat.markChannelRead(widget.channelId);
    _channelSub =
        _chat.streamChannelDoc(widget.channelId).listen(_onChannelUpdate);
  }

  void _onChannelUpdate(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    // Members (course/group use memberNames; dm uses names).
    final names = (data['memberNames'] ?? data['names'] ?? {}) as Map;
    final members = <String, String>{};
    names.forEach((k, v) => members[k.toString()] = v.toString());

    // Typing: anyone but me with a timestamp within the last 5 seconds.
    final typing = (data['typing'] as Map?) ?? {};
    final now = DateTime.now();
    final typers = <String>[];
    typing.forEach((k, v) {
      if (k.toString() == _uid) return;
      if (v is Timestamp && now.difference(v.toDate()).inSeconds < 5) {
        typers.add(members[k.toString()] ?? 'Someone');
      }
    });
    if (!mounted) return;
    setState(() {
      _members = members;
      _typingText = typers.isEmpty
          ? ''
          : typers.length == 1
              ? '${typers.first} is typing…'
              : '${typers.length} people are typing…';
    });
  }

  @override
  void dispose() {
    _typingClear?.cancel();
    _channelSub?.cancel();
    _chat.setTyping(widget.channelId, false);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------- typing ----------------

  void _onInputChanged(String value) {
    final now = DateTime.now();
    if (value.isNotEmpty &&
        now.difference(_lastTypingPing).inSeconds >= 3) {
      _lastTypingPing = now;
      _chat.setTyping(widget.channelId, true);
    }
    _typingClear?.cancel();
    _typingClear = Timer(const Duration(seconds: 4), () {
      _chat.setTyping(widget.channelId, false);
    });

    // @mention picker: show when the current word begins with '@'.
    final word = _currentWord(value);
    final canMention = _members.isNotEmpty;
    final show = canMention && word.startsWith('@');
    if (show != _showMentions) setState(() => _showMentions = show);
  }

  String _currentWord(String text) {
    final sel = _input.selection.baseOffset;
    final upto = (sel >= 0 && sel <= text.length) ? text.substring(0, sel) : text;
    final parts = upto.split(RegExp(r'\s'));
    return parts.isEmpty ? '' : parts.last;
  }

  void _insertMention(String name) {
    final text = _input.text;
    final sel = _input.selection.baseOffset;
    final head = sel >= 0 ? text.substring(0, sel) : text;
    final tail = sel >= 0 ? text.substring(sel) : '';
    final lastAt = head.lastIndexOf('@');
    if (lastAt < 0) return;
    final newHead = '${head.substring(0, lastAt)}@$name ';
    _input.text = newHead + tail;
    _input.selection =
        TextSelection.collapsed(offset: newHead.length);
    setState(() => _showMentions = false);
  }

  List<String> _extractMentions(String text) {
    final uids = <String>[];
    _members.forEach((uid, name) {
      if (text.contains('@$name')) uids.add(uid);
    });
    return uids;
  }

  // ---------------- sending ----------------

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final mentions = _extractMentions(text);
    _input.clear();
    _chat.setTyping(widget.channelId, false);
    try {
      await _chat.sendMessage(
        channelId: widget.channelId,
        text: text,
        senderName: _myName,
        senderRole: _myRole,
        mentions: mentions,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _sending = true);
    try {
      await _chat.sendImageMessage(
        channelId: widget.channelId,
        bytes: bytes,
        senderName: _myName,
        senderRole: _myRole,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  bool _isLecturer(String role) => role == 'admin' || role == 'event_admin';

  Future<void> _startDm(String otherUid, String otherName) async {
    final id = await _chat.openDm(
      otherUid: otherUid,
      otherName: otherName,
      myName: _myName,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(channelId: id, title: otherName),
      ),
    );
  }

  // ---------------- build ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff6f8ff),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 16)),
            Text(
              _typingText.isNotEmpty
                  ? _typingText
                  : widget.subtitle,
              style: TextStyle(
                fontSize: 11,
                fontStyle:
                    _typingText.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<
                List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
              stream: _chat.streamMessages(widget.channelId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!;
                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'No messages yet.\nSay hello to start the conversation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xff94a3b8)),
                      ),
                    ),
                  );
                }
                // New messages arrived while open → mark read.
                _chat.markChannelRead(widget.channelId);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(14),
                  itemCount: docs.length,
                  itemBuilder: (context, i) =>
                      _bubble(docs[i].id, docs[i].data()),
                );
              },
            ),
          ),
          if (_showMentions) _mentionPicker(),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _mentionPicker() {
    final word = _currentWord(_input.text).replaceFirst('@', '').toLowerCase();
    final matches = _members.entries
        .where((e) =>
            e.key != _uid &&
            (word.isEmpty || e.value.toLowerCase().contains(word)))
        .take(6)
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      color: Colors.white,
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final e in matches)
            ListTile(
              dense: true,
              leading: const Icon(Icons.alternate_email, size: 18),
              title: Text(e.value),
              onTap: () => _insertMention(e.value),
            ),
        ],
      ),
    );
  }

  Widget _bubble(String messageId, Map<String, dynamic> m) {
    final senderId = (m['senderId'] ?? '').toString();
    final senderName = (m['senderName'] ?? 'Student').toString();
    final role = (m['senderRole'] ?? 'student').toString();
    final text = (m['text'] ?? '').toString();
    final imageUrl = (m['imageUrl'] ?? '').toString();
    final mine = senderId == _uid;
    final lecturer = _isLecturer(role);
    final ts = m['createdAt'];
    final time = ts is Timestamp ? DateFormat('HH:mm').format(ts.toDate()) : '';
    final reactions = (m['reactions'] as Map?) ?? {};

    final bubbleColor = mine
        ? const Color(0xff2563eb)
        : (lecturer ? const Color(0xffede9fe) : Colors.white);
    final textColor = mine ? Colors.white : const Color(0xff0f172a);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!mine)
              GestureDetector(
                onTap: () => _startDm(senderId, senderName),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: lecturer
                              ? const Color(0xff7c3aed)
                              : const Color(0xff64748b),
                        ),
                      ),
                      if (lecturer) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff7c3aed),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Lecturer',
                            style: TextStyle(color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            GestureDetector(
              onLongPress: () => _pickReaction(messageId),
              child: Container(
                padding: imageUrl.isNotEmpty
                    ? const EdgeInsets.all(4)
                    : const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  border: mine
                      ? null
                      : Border.all(color: const Color(0xffe2e8f0)),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(14),
                    topRight: const Radius.circular(14),
                    bottomLeft: Radius.circular(mine ? 14 : 2),
                    bottomRight: Radius.circular(mine ? 2 : 14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (c, w, p) => p == null
                              ? w
                              : const SizedBox(
                                  width: 180,
                                  height: 180,
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                        ),
                      ),
                    if (text.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          top: imageUrl.isNotEmpty ? 6 : 0,
                          left: imageUrl.isNotEmpty ? 6 : 0,
                          bottom: imageUrl.isNotEmpty ? 4 : 0,
                        ),
                        child: _messageText(text, textColor),
                      ),
                  ],
                ),
              ),
            ),
            if (reactions.isNotEmpty) _reactionChips(messageId, reactions),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                time,
                style: const TextStyle(fontSize: 10, color: Color(0xff94a3b8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renders message text with @mentions highlighted.
  Widget _messageText(String text, Color baseColor) {
    final names = _members.values.toList()
      ..sort((a, b) => b.length.compareTo(a.length)); // longest first
    final spans = <TextSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      var matched = false;
      final at = rest.indexOf('@');
      if (at >= 0) {
        for (final name in names) {
          if (rest.startsWith('@$name', at)) {
            if (at > 0) {
              spans.add(TextSpan(text: rest.substring(0, at)));
            }
            spans.add(TextSpan(
              text: '@$name',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: baseColor == Colors.white
                    ? Colors.amberAccent
                    : const Color(0xff2563eb),
              ),
            ));
            rest = rest.substring(at + name.length + 1);
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        spans.add(TextSpan(text: rest));
        break;
      }
    }
    return RichText(
      text: TextSpan(style: TextStyle(color: baseColor), children: spans),
    );
  }

  Widget _reactionChips(String messageId, Map reactions) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        children: [
          for (final entry in reactions.entries)
            if ((entry.value as List).isNotEmpty)
              GestureDetector(
                onTap: () {
                  final mineReacted =
                      (entry.value as List).contains(_uid);
                  _chat.toggleReaction(
                    channelId: widget.channelId,
                    messageId: messageId,
                    emoji: entry.key.toString(),
                    add: !mineReacted,
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (entry.value as List).contains(_uid)
                        ? const Color(0xffdbeafe)
                        : const Color(0xfff1f5f9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xffe2e8f0)),
                  ),
                  child: Text(
                    '${entry.key} ${(entry.value as List).length}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _pickReaction(String messageId) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final e in _reactionEmojis)
                GestureDetector(
                  onTap: () => Navigator.pop(context, e),
                  child: Text(e, style: const TextStyle(fontSize: 30)),
                ),
            ],
          ),
        ),
      ),
    );
    if (emoji == null) return;
    await _chat.toggleReaction(
      channelId: widget.channelId,
      messageId: messageId,
      emoji: emoji,
      add: true,
    );
  }

  Widget _inputBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xffe2e8f0))),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: _sending ? null : _sendImage,
              icon: const Icon(Icons.image_outlined, color: Color(0xff64748b)),
              tooltip: 'Send image',
            ),
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                onChanged: _onInputChanged,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message…  (@ to mention)',
                  filled: true,
                  fillColor: const Color(0xfff1f5f9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xff2563eb),
              child: IconButton(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
