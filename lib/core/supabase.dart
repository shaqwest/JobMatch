import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool get isSupabaseConfigured {
  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  return url.isNotEmpty && key.isNotEmpty && url.startsWith('http');
}

Future<void> initSupabase() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  if (!isSupabaseConfigured) return;
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
}

SupabaseClient? get supabaseOrNull =>
    isSupabaseConfigured ? Supabase.instance.client : null;
