import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isSupabaseConfigured) {
      WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/jobs'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = supabaseOrNull!.auth.currentSession;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go(session == null ? '/login' : '/jobs');
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
