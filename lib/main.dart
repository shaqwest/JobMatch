import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/supabase.dart';
import 'core/theme.dart';
import 'features/chat/chat_bubble.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  runApp(const ProviderScope(child: JobMatchApp()));
}

class JobMatchApp extends StatelessWidget {
  const JobMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JobMatch',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
      builder: (ctx, child) => Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (overlayCtx) => ChatBubbleOverlay(child: child ?? const SizedBox.shrink()),
          ),
        ],
      ),
    );
  }
}
