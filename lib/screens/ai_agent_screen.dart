import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/ai_agent_service.dart';
import 'announcements_screen.dart';
import 'events_screen.dart';
import 'locations_screen.dart';
import 'reminders_screen.dart';
import 'resources_screen.dart';
import 'timetable_screen.dart';

enum AgentMode { voice, chat }

class AIAgentScreen extends StatefulWidget {
  const AIAgentScreen({super.key});

  @override
  State<AIAgentScreen> createState() => _AIAgentScreenState();
}

class AgentChatMessage {
  final String sender;
  final String text;
  final AIAgentReply? reply;

  const AgentChatMessage({
    required this.sender,
    required this.text,
    this.reply,
  });

  bool get isUser => sender == 'user';
}

class _AIAgentScreenState extends State<AIAgentScreen> {
  static const _welcomeText =
      'Hi, I am Canva. I can help with reminders, weekly study planning, Digital Hub resources, timetable, announcements, events, and campus navigation.';

  final agentService = AIAgentService();
  final messageController = TextEditingController();
  final scrollController = ScrollController();
  final speech = stt.SpeechToText();
  final tts = FlutterTts();

  final List<AgentChatMessage> messages = const [
    AgentChatMessage(sender: 'ai', text: _welcomeText),
  ].toList();

  AgentMode selectedMode = AgentMode.voice;
  AIAgentReply? latestReply;
  bool isLoading = false;
  bool speechAvailable = false;
  bool isListening = false;
  bool isSpeaking = false;
  bool voiceConversationActive = false;
  bool voiceRepliesEnabled = true;
  String studentName = 'Student';
  String voiceTranscript = '';
  String voiceReply = _welcomeText;

  @override
  void initState() {
    super.initState();
    latestReply = const AIAgentReply(text: _welcomeText);
    _loadStudentName();
    _initSpeech();
    _initTts();
  }

  Future<void> _loadStudentName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = (doc.data()?['name'] ?? '').toString().trim();
      final fallback = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email ?? 'Student').split('@').first;

      if (!mounted) return;
      setState(() => studentName = name.isEmpty ? fallback : name);
    } catch (_) {
      final fallback = (user.email ?? 'Student').split('@').first;
      if (mounted) setState(() => studentName = fallback);
    }
  }

  Future<void> _initSpeech() async {
    speechAvailable = await speech.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.62);
    await tts.setPitch(1.04);
    await tts.awaitSpeakCompletion(true);
  }

  Future<void> _sendText(String text, {bool fromVoice = false}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isLoading) return;

    setState(() {
      messages.add(AgentChatMessage(sender: 'user', text: trimmed));
      isLoading = true;
      voiceTranscript = trimmed;
      messageController.clear();
    });
    _scrollToBottom();

    final response = await agentService.handleMessage(
      userId: FirebaseAuth.instance.currentUser?.uid ?? '',
      message: trimmed,
    );

    if (!mounted) return;
    setState(() {
      messages.add(
        AgentChatMessage(sender: 'ai', text: response.text, reply: response),
      );
      latestReply = response;
      voiceReply = response.text;
      isLoading = false;
    });
    _scrollToBottom();

    if ((fromVoice || selectedMode == AgentMode.voice) && voiceRepliesEnabled) {
      await _speak(response.text);
    }

    if (fromVoice && mounted && voiceConversationActive) {
      await _startListening();
    }
  }

  Future<void> _toggleVoiceConversation() async {
    if (voiceConversationActive) {
      await _stopVoiceConversation();
      return;
    }

    setState(() => voiceConversationActive = true);
    if (voiceRepliesEnabled) {
      await _greetStudent();
    }
    if (mounted && voiceConversationActive) {
      await _startListening();
    }
  }

  Future<void> _greetStudent() async {
    final greeting = 'Hi $studentName, how can I assist you today?';
    final reply = AIAgentReply(text: greeting);

    if (!mounted) return;
    setState(() {
      latestReply = reply;
      voiceReply = greeting;
      messages.add(
        AgentChatMessage(sender: 'ai', text: greeting, reply: reply),
      );
    });
    _scrollToBottom();
    await _speak(greeting);
  }

  Future<void> _stopVoiceConversation() async {
    await speech.stop();
    await tts.stop();
    if (!mounted) return;
    setState(() {
      voiceConversationActive = false;
      isListening = false;
      isSpeaking = false;
    });
  }

  Future<void> _startListening() async {
    if (isLoading || isSpeaking) return;

    if (!speechAvailable) {
      await _initSpeech();
    }
    if (!speechAvailable) {
      _showMessage('Voice input is not available on this device.');
      setState(() => voiceConversationActive = false);
      return;
    }

    setState(() {
      isListening = true;
      voiceTranscript = '';
    });

    await speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        pauseFor: const Duration(milliseconds: 1100),
        listenFor: const Duration(seconds: 24),
      ),
      onResult: (result) {
        if (!mounted) return;
        setState(() => voiceTranscript = result.recognizedWords);
        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          speech.stop();
          setState(() => isListening = false);
          _sendText(result.recognizedWords, fromVoice: true);
        }
      },
    );
  }

  Future<void> _speak(String text) async {
    final speechText = _speechTextFor(text);
    if (speechText.isEmpty) return;

    await tts.stop();
    if (!mounted) return;
    setState(() => isSpeaking = true);
    await tts.speak(speechText);
    if (!mounted) return;
    setState(() => isSpeaking = false);
  }

  String _speechTextFor(String text) {
    return text
        .split('\n')
        .where((line) => !line.trim().startsWith('http'))
        .join('. ')
        .replaceAll(RegExp(r'https?:\/\/\S+'), 'link available on screen')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _openAgentTarget(AIAgentReply reply) {
    final target = reply.navigationTarget;
    if (target == null) return;

    final page = switch (target) {
      AgentNavigationTarget.announcements => const AnnouncementsScreen(),
      AgentNavigationTarget.resources => ResourcesScreen(
        initialKeyword: reply.query,
      ),
      AgentNavigationTarget.timetable => const TimetableScreen(),
      AgentNavigationTarget.reminders => const RemindersScreen(),
      AgentNavigationTarget.locations => const LocationsScreen(),
      AgentNavigationTarget.events => const EventsScreen(),
    };

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _bubble(AgentChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: message.isUser ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : Colors.black87,
              ),
            ),
            if (!message.isUser &&
                message.reply?.navigationTarget != null &&
                message.reply?.actionLabel != null) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openAgentTarget(message.reply!),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(message.reply!.actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SegmentedButton<AgentMode>(
        segments: const [
          ButtonSegment(
            value: AgentMode.voice,
            icon: Icon(Icons.mic),
            label: Text('Voice'),
          ),
          ButtonSegment(
            value: AgentMode.chat,
            icon: Icon(Icons.chat_bubble_outline),
            label: Text('Chat'),
          ),
        ],
        selected: {selectedMode},
        onSelectionChanged: (value) async {
          if (value.first == AgentMode.chat) {
            await _stopVoiceConversation();
          }
          setState(() => selectedMode = value.first);
        },
      ),
    );
  }

  Widget _voiceSurface() {
    final status = isSpeaking
        ? 'Speaking'
        : isListening
        ? 'Listening'
        : voiceConversationActive
        ? 'Ready'
        : 'Stopped';

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xffd8e2f1)),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 8),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blue.shade50,
                      child: const Icon(Icons.smart_toy, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Canva',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    FilterChip(
                      label: Text(status),
                      selected: voiceConversationActive,
                      onSelected: (_) => _toggleVoiceConversation(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: isLoading ? null : _toggleVoiceConversation,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: voiceConversationActive
                          ? Colors.red.shade50
                          : Colors.blue.shade50,
                      border: Border.all(
                        color: voiceConversationActive
                            ? Colors.red
                            : Colors.blue,
                        width: 3,
                      ),
                    ),
                    child: Icon(
                      voiceConversationActive ? Icons.stop : Icons.mic,
                      size: 58,
                      color: voiceConversationActive ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  voiceConversationActive
                      ? 'Tap to stop'
                      : 'Start voice conversation',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Voice replies'),
                  value: voiceRepliesEnabled,
                  onChanged: (value) async {
                    if (!value) {
                      await tts.stop();
                    }
                    setState(() => voiceRepliesEnabled = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _voicePanel(
            icon: Icons.person,
            title: 'Student',
            text: voiceTranscript.isEmpty ? '...' : voiceTranscript,
          ),
          _voicePanel(
            icon: Icons.smart_toy,
            title: 'Canva',
            text: voiceReply,
            reply: latestReply,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _examples
                .map(
                  (example) => ActionChip(
                    label: Text(example),
                    onPressed: isLoading
                        ? null
                        : () => _sendText(example, fromVoice: true),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _voicePanel({
    required IconData icon,
    required String title,
    required String text,
    AIAgentReply? reply,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffd8e2f1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text),
          if (reply?.navigationTarget != null &&
              reply?.actionLabel != null) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _openAgentTarget(reply),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(reply!.actionLabel!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chatSurface() {
    return Expanded(
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _examples.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(_examples[index]),
                  onPressed: () => messageController.text = _examples[index],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) => _bubble(messages[index]),
            ),
          ),
          if (isLoading) const LinearProgressIndicator(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        hintText: 'Ask Canva about campus tasks...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _sendText(messageController.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: isLoading
                        ? null
                        : () => _sendText(messageController.text),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> get _examples => const [
    'Canva, set a reminder for 20 Jun 10 pm ITM3206 class test',
    'What should I do this week?',
    'Show my upcoming due dates this week',
    'Open Canvas LMS',
    'Where is Finance Office?',
    'Show latest announcements',
  ];

  @override
  void dispose() {
    speech.stop();
    tts.stop();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Canva Campus Agent')),
      body: Column(
        children: [
          _modeSelector(),
          if (selectedMode == AgentMode.voice)
            _voiceSurface()
          else
            _chatSurface(),
        ],
      ),
    );
  }
}
