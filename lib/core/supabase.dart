import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _env(String key) {
  const fromDefine = String.fromEnvironment(key);
  if (fromDefine.isNotEmpty) return fromDefine;
  try {
    if (!dotenv.isInitialized) return '';
    return dotenv.env[key] ?? '';
  } catch (_) {
    return '';
  }
}

bool get isSupabaseConfigured {
  try {
    final url = _env('SUPABASE_URL');
    final key = _env('SUPABASE_ANON_KEY');
    return url.isNotEmpty && key.isNotEmpty && url.startsWith('http');
  } catch (_) {
    return false;
  }
}

Future<void> initSupabase() async {
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  if (!isSupabaseConfigured) return;
  await Supabase.initialize(
    url: _env('SUPABASE_URL'),
    anonKey: _env('SUPABASE_ANON_KEY'),
  );
}

SupabaseClient? get supabaseOrNull {
  try {
    return isSupabaseConfigured ? Supabase.instance.client : null;
  } catch (_) {
    return null;
  }
}
