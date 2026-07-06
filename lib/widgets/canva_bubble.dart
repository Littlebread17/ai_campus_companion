import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/ai_agent_screen.dart';

/// Root navigator key so the floating bubble can push the Canva chat from above
/// the app's navigator (it lives in MaterialApp.builder).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// True while the Canva chat is open, so the bubble hides itself.
final ValueNotifier<bool> canvaChatOpen = ValueNotifier(false);

/// A draggable floating "Canva" chat bubble shown on every screen (once the
/// student is signed in). Tapping opens the AI agent chat.
class CanvaBubble extends StatefulWidget {
  const CanvaBubble({super.key});

  @override
  State<CanvaBubble> createState() => _CanvaBubbleState();
}

class _CanvaBubbleState extends State<CanvaBubble> {
  Offset? _pos;

  void _open() {
    if (canvaChatOpen.value) return;
    canvaChatOpen.value = true;
    rootNavigatorKey.currentState
        ?.push(
          MaterialPageRoute(
            builder: (_) => const AIAgentScreen(),
            settings: const RouteSettings(name: '/canva'),
          ),
        )
        .then((_) => canvaChatOpen.value = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.data == null) return const SizedBox.shrink();
        return ValueListenableBuilder<bool>(
          valueListenable: canvaChatOpen,
          builder: (context, open, _) {
            if (open) return const SizedBox.shrink();
            final size = MediaQuery.of(context).size;
            final pos = _pos ??
                Offset(size.width - 76, size.height - 168);
            return Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    final next = (pos) + d.delta;
                    _pos = Offset(
                      next.dx.clamp(8.0, size.width - 64),
                      next.dy.clamp(40.0, size.height - 100),
                    );
                  });
                },
                child: FloatingActionButton(
                  heroTag: 'canva-bubble',
                  onPressed: _open,
                  backgroundColor: const Color(0xff7c3aed),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.smart_toy),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
