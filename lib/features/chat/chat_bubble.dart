import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chat_provider.dart';

class ChatBubbleOverlay extends ConsumerStatefulWidget {
  final Widget child;
  const ChatBubbleOverlay({super.key, required this.child});

  @override
  ConsumerState<ChatBubbleOverlay> createState() => _ChatBubbleOverlayState();
}

class _ChatBubbleOverlayState extends ConsumerState<ChatBubbleOverlay> {
  bool _open = false;
  bool _minimized = false;
  Offset _pos = const Offset(16, 120);
  final _input = TextEditingController();
  final _scroll = ScrollController();

  void _send() {
    final t = _input.text;
    if (t.trim().isEmpty) return;
    _input.clear();
    ref.read(chatProvider.notifier).send(t);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider);
    return Stack(
      children: [
        widget.child,
        if (!_open)
          Positioned(
            right: 16,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: FloatingActionButton.small(
              onPressed: () => setState(() => _open = true),
              backgroundColor: const Color(0xFF09090B),
              foregroundColor: Colors.white,
              child: const Icon(Icons.chat_bubble_outline, size: 18),
            ),
          ),
        if (_open)
          Positioned(
            left: _pos.dx,
            top: _pos.dy,
            child: FocusTraversalGroup(
              child: GestureDetector(
                onPanUpdate: (d) => setState(() => _pos += d.delta),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 340,
                    height: _minimized ? 48 : 420,
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE4E4E7)), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) => setState(() => _pos += d.delta),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE4E4E7))), borderRadius: BorderRadius.vertical(top: Radius.circular(12)), color: Colors.white),
                            child: Row(children: [
                              const Icon(Icons.smart_toy_outlined, size: 16),
                              const SizedBox(width: 8),
                              Text('Assistant', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              Text('drag header to move', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF71717A), fontSize: 10)),
                              const Spacer(),
                              IconButton(icon: Icon(_minimized ? Icons.open_in_full : Icons.minimize, size: 16), onPressed: () => setState(() => _minimized = !_minimized), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => setState(() => _open = false), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                            ]),
                          ),
                        ),
                        if (!_minimized) ...[
                          Expanded(
                            child: SelectionArea(
                              child: ListView.builder(
                                controller: _scroll,
                                padding: const EdgeInsets.all(12),
                                itemCount: messages.isEmpty ? 1 : messages.length,
                                itemBuilder: (_, i) {
                                  if (messages.isEmpty) return Text('Ask about jobs, CV tips, or interview prep.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF71717A)));
                                  final m = messages[i];
                                  final isUser = m.role == 'user';
                                  return Align(
                                    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      constraints: const BoxConstraints(maxWidth: 260),
                                      decoration: BoxDecoration(color: isUser ? const Color(0xFF09090B) : const Color(0xFFF4F4F5), borderRadius: BorderRadius.circular(12), border: isUser ? null : Border.all(color: const Color(0xFFE4E4E7))),
                                      child: SelectableText(m.content, style: TextStyle(fontSize: 13, color: isUser ? Colors.white : const Color(0xFF27272A))),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Expanded(
                                child: TextField(
                                  controller: _input,
                                  autofocus: false,
                                  decoration: const InputDecoration(hintText: 'Ask something', isDense: true),
                                  onSubmitted: (_) => _send(),
                                  minLines: 1,
                                  maxLines: 5,
                                  keyboardType: TextInputType.multiline,
                                  textInputAction: TextInputAction.send,
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(onPressed: _send, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)), child: const Icon(Icons.send, size: 16)),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
