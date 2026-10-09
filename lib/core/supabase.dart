import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _env(String key) {
  if (key == 'SUPABASE_URL') {
    const v = String.fromEnvironment('SUPABASE_URL');
    if (v.isNotEmpty) return v;
  }
  if (key == 'SUPABASE_ANON_KEY') {
    const v = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (v.isNotEmpty) return v;
  }
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
  } catch (_) {
    // If .env is missing (e.g. web/demo), we just rely on --dart-define
  }
  
  if (!isSupabaseConfigured) {
    // Debug: check if it's configured via --dart-define
    debugPrint('Supabase not configured via .env or --dart-define');
    return;
  }
  
  await Supabase.initialize(
    url: _env('SUPABASE_URL'),
    anonKey: _env('SUPABASE_ANON_KEY'),
  );
  debugPrint('Supabase initialized with URL: ${_env('SUPABASE_URL')}');
}

SupabaseClient? get supabaseOrNull {
  try {
    return isSupabaseConfigured ? Supabase.instance.client : null;
  } catch (_) {
    return null;
  }
}
