import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/ai_agent_service.dart';
import '../services/llm_service.dart';
import 'announcements_screen.dart';
import 'events_screen.dart';
import 'locations_screen.dart';
import 'calendar_screen.dart';
import 'resources_screen.dart';
import 'timetable_screen.dart';

enum AgentMode { voice, chat }

class AIAgentScreen extends StatefulWidget {
  const AIAgentScreen({super.key, this.initialText});

  /// Optional text to pre-fill the chat input (from the Home "Ask Canva" bar).
  final String? initialText;

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

class _AIAgentScreenState extends State<AIAgentScreen>
    with TickerProviderStateMixin {
  static const _welcomeText =
      'Hi, I am Canva. I can help with reminders, weekly study planning, Digital Hub resources, timetable, announcements, events, and campus navigation.';

  final agentService = AIAgentService();
  late final LlmService llmService = LlmService(agentService);
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
  bool hasGreetedStudent = false;
  bool voiceResultSubmitted = false;
  String studentName = 'Student';
  String voiceTranscript = '';
  String voiceReply = _welcomeText;
  Timer? noSpeechTimer;

  late final AnimationController _pulse;
  late final AnimationController _rotate;

  @override
  void initState() {
    super.initState();
    latestReply = const AIAgentReply(text: _welcomeText);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _rotate = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
    _loadStudentName();
    _initSpeech();
    _initTts();

    // Pre-fill from the Home "Ask Canva" bar and switch to chat mode.
    final seed = widget.initialText?.trim() ?? '';
    if (seed.isNotEmpty) {
      selectedMode = AgentMode.chat;
      messageController.text = seed;
    }
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
    speechAvailable = await speech.initialize(
      onStatus: _handleSpeechStatus,
      onError: _handleSpeechError,
    );
    if (mounted) setState(() {});
  }

  Future<void> _initTts() async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.5);
    await tts.setPitch(1.02);
    await tts.awaitSpeakCompletion(true);
    await _selectBestVoice();
  }

  /// Picks the most natural installed English voice (prefers enhanced/neural/
  /// network voices) so the assistant sounds less robotic. Falls back silently.
  Future<void> _selectBestVoice() async {
    try {
      final raw = await tts.getVoices;
      if (raw is! List) return;
      final en = raw
          .whereType<Map>()
          .where(
            (v) =>
                (v['locale'] ?? '').toString().toLowerCase().startsWith('en'),
          )
          .toList();
      if (en.isEmpty) return;

      Map? best;
      for (final v in en) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        if (name.contains('neural') ||
            name.contains('enhanced') ||
            name.contains('network') ||
            name.contains('premium')) {
          best = v;
          break;
        }
      }
      best ??= en.first;
      await tts.setVoice({
        'name': (best['name'] ?? '').toString(),
        'locale': (best['locale'] ?? 'en-US').toString(),
      });
    } catch (_) {
      // Keep the default voice if enumeration is unsupported.
    }
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

    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final AIAgentReply response;
    if (llmService.isConfigured) {
      final llmReply = await llmService.handleMessage(
        userId: userId,
        message: trimmed,
      );
      response =
          llmReply ??
          const AIAgentReply(
            text:
                "I can't reach my brain right now. Check your connection and try again.",
          );
    } else {
      response = await agentService.handleMessage(
        userId: userId,
        message: trimmed,
      );
    }

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
  }

  Future<void> _toggleVoiceConversation() async {
    if (voiceConversationActive) {
      await _stopVoiceConversation();
      return;
    }

    setState(() => voiceConversationActive = true);
    if (voiceRepliesEnabled && !hasGreetedStudent) {
      hasGreetedStudent = true;
      await _greetStudent();
      await Future<void>.delayed(const Duration(milliseconds: 400));
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
    noSpeechTimer?.cancel();
    voiceResultSubmitted = true;
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

    noSpeechTimer?.cancel();
    voiceResultSubmitted = true;
    setState(() {
      isListening = false;
      voiceTranscript = '';
    });

    await speech.cancel();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted || !voiceConversationActive) return;
    voiceResultSubmitted = false;

    final started = await _beginSpeechSession();

    if (!mounted) return;
    if (!started) {
      setState(() {
        voiceConversationActive = false;
        isListening = false;
      });
      _showMessage('Voice input could not start. Tap the orb to try again.');
      return;
    }

    setState(() => isListening = true);
    noSpeechTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || voiceTranscript.trim().isNotEmpty) return;
      unawaited(_endSilentTurn());
    });
  }

  Future<bool> _beginSpeechSession() async {
    final started = await speech.listen(
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
        pauseFor: const Duration(seconds: 8),
        listenFor: const Duration(seconds: 45),
      ),
      onResult: (result) {
        if (!mounted) return;
        final words = result.recognizedWords.trim();
        setState(() => voiceTranscript = words);
        if (words.isNotEmpty) noSpeechTimer?.cancel();
        if (result.finalResult && words.isNotEmpty) {
          unawaited(_submitVoiceResult(words));
        }
      },
    );
    return started == true;
  }

  void _handleSpeechStatus(String status) {
    if (!mounted || voiceResultSubmitted || !isListening) return;
    if (status != 'done' && status != 'notListening') return;

    final words = voiceTranscript.trim();
    if (words.isEmpty) {
      unawaited(_endSilentTurn());
    } else {
      unawaited(_submitVoiceResult(words));
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    if (!mounted || voiceResultSubmitted) return;
    final noSpeech =
        error.errorMsg.contains('no_match') ||
        error.errorMsg.contains('speech_timeout');
    if (noSpeech) {
      final words = voiceTranscript.trim();
      if (words.isNotEmpty) {
        unawaited(_submitVoiceResult(words));
        return;
      }
    }
    unawaited(
      _endVoiceTurn(
        noSpeech
            ? 'No speech detected. Tap the orb to try again.'
            : 'Voice input error: ${error.errorMsg}',
      ),
    );
  }

  Future<void> _submitVoiceResult(String words) async {
    if (voiceResultSubmitted) return;
    voiceResultSubmitted = true;
    noSpeechTimer?.cancel();
    await speech.stop();
    if (!mounted) return;
    setState(() {
      isListening = false;
      voiceConversationActive = false;
    });
    await _sendText(words, fromVoice: true);
  }

  Future<void> _endSilentTurn() =>
      _endVoiceTurn('No speech detected. Tap the orb to try again.');

  Future<void> _endVoiceTurn(String message) async {
    if (voiceResultSubmitted) return;
    voiceResultSubmitted = true;
    noSpeechTimer?.cancel();
    await speech.stop();
    if (!mounted) return;
    setState(() {
      isListening = false;
      voiceConversationActive = false;
    });
    _showMessage(message);
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
      AgentNavigationTarget.reminders => const CalendarScreen(initialTab: 2),
      AgentNavigationTarget.locations => LocationsScreen(
        initialQuery: reply.query,
      ),
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

  // Iron Man HUD palette — one cool cyan-blue family across every state, with
  // brightness/saturation changing rather than a new hue.
  Color get _stateColor {
    if (isSpeaking) return const Color(0xff5be8ff); // bright cyan
    if (isListening) return const Color(0xff22d3ee); // cyan
    if (isLoading) return const Color(0xffff9a3c); // stark orange (alert)
    return const Color(0xff4fc3ff); // steady blue
  }

  double get _energy {
    if (isListening) return 1.0;
    if (isSpeaking) return 0.85;
    if (isLoading) return 0.6;
    return 0.28;
  }

  String get _statusText {
    if (isSpeaking) return 'Speaking…';
    if (isListening) return 'Listening…';
    if (isLoading) return 'Thinking…';
    if (voiceConversationActive) return 'Tap the orb to stop';
    return 'Tap the orb to start';
  }

  Widget _voiceModeView() {
    final color = _stateColor;
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.1,
          colors: [Color(0xff0a2138), Color(0xff030812)],
        ),
      ),
      child: Stack(
        children: [
          // Faint HUD grid background.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _HudGridPainter(color: color)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _hudTopBar(color),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: isLoading || isSpeaking
                      ? null
                      : _toggleVoiceConversation,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_pulse, _rotate]),
                    builder: (context, _) => CustomPaint(
                      size: const Size(300, 300),
                      painter: _ArcReactorPainter(
                        pulse: _pulse.value,
                        rotate: _rotate.value,
                        color: color,
                        energy: _energy,
                        speaking: isSpeaking,
                        listening: isListening,
                      ),
                      child: SizedBox(
                        width: 300,
                        height: 300,
                        child: Center(
                          child: Icon(
                            voiceConversationActive
                                ? (isListening ? Icons.mic : Icons.graphic_eq)
                                : Icons.mic_none,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  _statusText.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _hudTranscriptPanel(color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudTopBar(Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_back, color: color.withValues(alpha: 0.8)),
          ),
          const Spacer(),
          Column(
            children: [
              Text(
                'C A N V A',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  fontSize: 15,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'CAMPUS ASSISTANT · v2',
                style: TextStyle(
                  color: color.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Switch to chat',
            onPressed: () async {
              await _stopVoiceConversation();
              setState(() => selectedMode = AgentMode.chat);
            },
            icon: Icon(
              Icons.chat_bubble_outline,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudTranscriptPanel(Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (voiceTranscript.isNotEmpty) ...[
              Text(
                '> USER',
                style: TextStyle(
                  color: color.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                voiceTranscript,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              '> CANVA',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              voiceReply,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 15,
                height: 1.4,
                fontFamily: 'monospace',
              ),
            ),
            if (latestReply?.navigationTarget != null &&
                latestReply?.actionLabel != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _openAgentTarget(latestReply!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color.withValues(alpha: 0.7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: Text(
                  latestReply!.actionLabel!.toUpperCase(),
                  style: const TextStyle(
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  voiceRepliesEnabled ? Icons.volume_up : Icons.volume_off,
                  color: color.withValues(alpha: 0.55),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  'AUDIO OUTPUT',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.55),
                    fontSize: 11,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                Switch(
                  value: voiceRepliesEnabled,
                  activeThumbColor: color,
                  onChanged: (value) async {
                    if (!value) await tts.stop();
                    setState(() => voiceRepliesEnabled = value);
                  },
                ),
              ],
            ),
          ],
        ),
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
    'Canva, set a reminder for my assignment tomorrow 10 pm',
    'What should I do this week?',
    'Show my upcoming due dates this week',
    'Open Canvas LMS',
    'Where is Finance Office?',
    'Show latest announcements',
  ];

  @override
  void dispose() {
    noSpeechTimer?.cancel();
    _pulse.dispose();
    _rotate.dispose();
    speech.stop();
    tts.stop();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (selectedMode == AgentMode.voice) {
      return Scaffold(
        backgroundColor: const Color(0xff0b1020),
        body: _voiceModeView(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Canva Campus Agent'),
        actions: [
          IconButton(
            tooltip: 'Voice mode',
            onPressed: () => setState(() => selectedMode = AgentMode.voice),
            icon: const Icon(Icons.graphic_eq),
          ),
        ],
      ),
      body: Column(children: [_modeSelector(), _chatSurface()]),
    );
  }
}

/// Arc-reactor style HUD orb — layered rings, rotating tick marks, a glowing
/// core and an animated waveform when Canva is speaking.
class _ArcReactorPainter extends CustomPainter {
  final double pulse; // 0..1
  final double rotate; // 0..1
  final Color color;
  final double energy; // 0..1
  final bool speaking;
  final bool listening;

  _ArcReactorPainter({
    required this.pulse,
    required this.rotate,
    required this.color,
    required this.energy,
    required this.speaking,
    required this.listening,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.width / 2 - 4;

    // Outermost rotating tick ring (like the Iron Man HUD).
    _drawTickRing(canvas, center, maxR, color, rotate);

    // Segmented ring (two gaps at 12 & 6 o'clock).
    _drawSegmentedRing(
      canvas,
      center,
      maxR - 12,
      color.withValues(alpha: 0.6),
      rotate * -1,
    );

    // Expanding pulse ripples driven by state energy.
    for (var i = 0; i < 3; i++) {
      final phase = (pulse + i / 3) % 1.0;
      final r = maxR * (0.42 + 0.5 * phase);
      final opacity = (1 - phase) * 0.55 * (0.3 + 0.7 * energy);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(center, r, ring);
    }

    // Waveform arc when Canva is speaking; steady bright ring otherwise.
    if (speaking) {
      _drawWaveform(canvas, center, maxR * 0.44, color);
    }

    // Inner solid ring around the core.
    final innerR = maxR * 0.42;
    canvas.drawCircle(
      center,
      innerR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: 0.85),
    );

    // Glowing core (arc reactor).
    final wobble = 0.04 * math.sin(pulse * 2 * math.pi) * (0.4 + energy);
    final coreR = maxR * (0.30 + wobble);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 1.0),
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: coreR * 1.9));
    canvas.drawCircle(center, coreR * 1.9, glow);

    canvas.drawCircle(
      center,
      coreR,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(center, coreR * 0.55, Paint()..color = color);

    // Faint cross-hair through the core when idle-ish (adds HUD feel).
    if (!listening) {
      final cross = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1;
      canvas.drawLine(
        Offset(center.dx - coreR, center.dy),
        Offset(center.dx + coreR, center.dy),
        cross,
      );
      canvas.drawLine(
        Offset(center.dx, center.dy - coreR),
        Offset(center.dx, center.dy + coreR),
        cross,
      );
    }
  }

  void _drawTickRing(
    Canvas canvas,
    Offset center,
    double r,
    Color color,
    double rotate,
  ) {
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.4;
    const ticks = 60;
    for (var i = 0; i < ticks; i++) {
      final angle = (i / ticks) * 2 * math.pi + rotate * 2 * math.pi;
      final longTick = i % 5 == 0;
      final innerLen = longTick ? 10.0 : 5.0;
      final p1 = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * (r - innerLen),
        center.dy + math.sin(angle) * (r - innerLen),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  void _drawSegmentedRing(
    Canvas canvas,
    Offset center,
    double r,
    Color color,
    double rotate,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    // Three arcs with gaps
    for (var i = 0; i < 3; i++) {
      final start = rotate * 2 * math.pi + i * (2 * math.pi / 3) + 0.15;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r),
        start,
        (2 * math.pi / 3) - 0.3,
        false,
        paint,
      );
    }
  }

  void _drawWaveform(Canvas canvas, Offset center, double r, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4;
    const bars = 24;
    for (var i = 0; i < bars; i++) {
      final angle = (i / bars) * 2 * math.pi + rotate * math.pi * 0.5;
      final t = (pulse * 4 + i * 0.35) % 1.0;
      final h = 6 + (16 * (0.5 + 0.5 * math.sin(t * 2 * math.pi)));
      final p1 = Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      );
      final p2 = Offset(
        center.dx + math.cos(angle) * (r + h),
        center.dy + math.sin(angle) * (r + h),
      );
      canvas.drawLine(p1, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcReactorPainter old) =>
      old.pulse != pulse ||
      old.rotate != rotate ||
      old.color != color ||
      old.energy != energy ||
      old.speaking != speaking ||
      old.listening != listening;
}

/// Very faint HUD grid + corner brackets across the whole screen background.
class _HudGridPainter extends CustomPainter {
  final Color color;
  _HudGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const step = 44.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Corner brackets.
    final bracket = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    const bl = 22.0;
    const pad = 14.0;
    // Top-left
    canvas.drawLine(
      const Offset(pad, pad),
      const Offset(pad + bl, pad),
      bracket,
    );
    canvas.drawLine(
      const Offset(pad, pad),
      const Offset(pad, pad + bl),
      bracket,
    );
    // Top-right
    canvas.drawLine(
      Offset(size.width - pad - bl, pad),
      Offset(size.width - pad, pad),
      bracket,
    );
    canvas.drawLine(
      Offset(size.width - pad, pad),
      Offset(size.width - pad, pad + bl),
      bracket,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(pad, size.height - pad),
      Offset(pad + bl, size.height - pad),
      bracket,
    );
    canvas.drawLine(
      Offset(pad, size.height - pad - bl),
      Offset(pad, size.height - pad),
      bracket,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - pad - bl, size.height - pad),
      Offset(size.width - pad, size.height - pad),
      bracket,
    );
    canvas.drawLine(
      Offset(size.width - pad, size.height - pad - bl),
      Offset(size.width - pad, size.height - pad),
      bracket,
    );
  }

  @override
  bool shouldRepaint(covariant _HudGridPainter old) => old.color != color;
}
