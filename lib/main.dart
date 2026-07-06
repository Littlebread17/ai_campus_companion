import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'services/notification_service.dart';
import 'widgets/canva_bubble.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    // If Firebase itself fails to start, show an error instead of a blank
    // white screen so the problem is visible.
    debugPrint('Firebase init failed: $e\n$st');
    runApp(_StartupErrorApp(message: 'Firebase failed to initialize:\n$e'));
    return;
  }

  // Notification setup must never block the app from rendering. On web it can
  // throw (missing service worker / VAPID key); we fire it without awaiting and
  // swallow errors so the UI always loads.
  unawaited(_initNotificationsSafely());

  runApp(const AICampusCompanionApp());
}

Future<void> _initNotificationsSafely() async {
  try {
    await NotificationService().initialize();
  } catch (e, st) {
    debugPrint('Notification init skipped: $e\n$st');
  }
}

class AICampusCompanionApp extends StatelessWidget {
  const AICampusCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Campus Companion',
      debugShowCheckedModeBanner: false,
      navigatorKey: rootNavigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2563eb),
          primary: const Color(0xff2563eb),
          secondary: const Color(0xff7c3aed),
          tertiary: const Color(0xff06b6d4),
          surface: Colors.white,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff6f8ff),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      builder: (context, child) {
        // Overlay the always-available Canva chat bubble above every screen.
        return Stack(
          children: [
            ?child,
            const CanvaBubble(),
          ],
        );
      },
      home: const AuthWrapper(),
    );
  }
}

class _StartupErrorApp extends StatelessWidget {
  final String message;
  const _StartupErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
