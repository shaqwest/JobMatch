import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

class ChatMessage {
  final String role;
  final String content;
  const ChatMessage(this.role, this.content);
}

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super(const []);
  bool _sending = false;
  bool get sending => _sending;

  Future<void> send(String text) async {
    if (text.trim().isEmpty || _sending) return;
    state = [...state, ChatMessage('user', text.trim())];
    _sending = true;
    try {
      final c = supabaseOrNull;
      if (c != null && isSupabaseConfigured) {
        final res = await c.functions.invoke('chat-proxy', body: {'message': text});
        final reply = (res.data is Map ? res.data['reply'] : null)?.toString() ?? 'No reply';
        state = [...state, ChatMessage('assistant', reply)];
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
        state = [...state, const ChatMessage('assistant', 'Demo mode: connect Supabase + 9Router to enable AI. Ask about jobs, CV, or interview prep.')];
      }
    } catch (e) {
      state = [...state, ChatMessage('assistant', 'Error: $e')];
    } finally {
      _sending = false;
    }
  }

  void clear() => state = [];
}

final chatProvider = StateNotifierProvider<ChatNotifier, List<ChatMessage>>((_) => ChatNotifier());
