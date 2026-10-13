import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';

class ChatMessage {
  final String role;
  final String content;
  const ChatMessage(this.role, this.content);
}

class ChatState {
  final List<ChatMessage> messages;
  final bool sending;
  const ChatState({this.messages = const [], this.sending = false});
  ChatState copyWith({List<ChatMessage>? messages, bool? sending}) =>
      ChatState(messages: messages ?? this.messages, sending: sending ?? this.sending);
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(const ChatState());

  Future<void> send(String text) async {
    if (text.trim().isEmpty || state.sending) return;
    state = state.copyWith(messages: [...state.messages, ChatMessage('user', text.trim())], sending: true);
    try {
      final c = supabaseOrNull;
      if (c != null && isSupabaseConfigured) {
        final res = await c.functions.invoke('chat-proxy', body: {'message': text}).timeout(const Duration(seconds: 25));
        final reply = (res.data is Map ? res.data['reply'] : null)?.toString() ?? 'No reply';
        state = state.copyWith(messages: [...state.messages, ChatMessage('assistant', reply)], sending: false);
      } else {
        await Future.delayed(const Duration(milliseconds: 700));
        state = state.copyWith(messages: [...state.messages, const ChatMessage('assistant', 'Demo mode: connect Supabase + 9Router to enable AI. Ask about jobs, CV, or interview prep.')], sending: false);
      }
    } catch (e) {
      state = state.copyWith(messages: [...state.messages, ChatMessage('assistant', 'Error: $e')], sending: false);
    }
  }

  void clear() => state = const ChatState();
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((_) => ChatNotifier());
