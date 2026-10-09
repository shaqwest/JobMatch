import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  String? _err;

  Future<void> _signIn() async {
    if (!isSupabaseConfigured) {
      context.go('/jobs');
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      await supabaseOrNull!.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );
      if (mounted) context.go('/jobs');
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signUp() async {
    if (!isSupabaseConfigured) {
      context.go('/profile');
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      await supabaseOrNull!.auth.signUp(
        email: _email.text.trim(),
        password: _pass.text,
      );
      if (mounted) context.go('/jobs');
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('JobMatch', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Sign in to see matched jobs for Indonesia', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF71717A))),
                const SizedBox(height: 24),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(controller: _pass, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                if (_err != null) ...[
                  const SizedBox(height: 12),
                  Text(_err!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12)),
                ],
                const SizedBox(height: 20),
                FilledButton(onPressed: _loading ? null : _signIn, child: Text(_loading ? 'Please wait' : 'Sign in')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _loading ? null : _signUp, child: const Text('Create account')),
                if (!isSupabaseConfigured) ...[
                  const SizedBox(height: 12),
                  Text('Supabase not configured — tap any button to continue in demo mode.', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF71717A))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
