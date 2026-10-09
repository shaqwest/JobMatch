import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

final authStateProvider = StreamProvider((ref) {
  final c = supabaseOrNull;
  if (c == null) return const Stream.empty();
  return c.auth.onAuthStateChange.map((e) => e.session);
});

final isLoggedInProvider = Provider<bool>((ref) {
  final c = supabaseOrNull;
  if (c == null) return true;
  return c.auth.currentSession != null;
});
