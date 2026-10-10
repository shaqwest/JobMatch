import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase.dart';
import 'profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final _name = TextEditingController(text: ref.read(profileProvider).fullName);
  late final _email = TextEditingController(text: ref.read(profileProvider).email);
  late final _phone = TextEditingController(text: ref.read(profileProvider).phone);
  late final _location = TextEditingController(text: ref.read(profileProvider).location);
  late final _summary = TextEditingController(text: ref.read(profileProvider).summary);
  late final _skills = TextEditingController(text: ref.read(profileProvider).skills.join(', '));
  late final _exp = TextEditingController(text: ref.read(profileProvider).experience);
  late final _edu = TextEditingController(text: ref.read(profileProvider).education);
  String _prefType = 'Any';
  bool _saving = false;
  bool _parsing = false;

  @override
  void initState() {
    super.initState();
    _prefType = ref.read(profileProvider).prefType;
  }

  Future<void> _pickCv() async {
    setState(() => _parsing = true);
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
      if (res == null || res.files.isEmpty) return;
      final bytes = res.files.single.bytes;
      if (bytes == null) return;
      if (!isSupabaseConfigured) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo: CV parsed locally. Fill manually for now.')));
        return;
      }
      final fileName = res.files.single.name;
      final user = supabaseOrNull!.auth.currentUser;
      if (user == null) return;
      final storagePath = '${user.id}/$fileName';
      await supabaseOrNull!.storage.from('cv_pdfs').uploadBinary(storagePath, bytes, fileOptions: const FileOptions(upsert: true));
      final result = await supabaseOrNull!.functions.invoke('cv-parse', body: {'path': storagePath});
      final data = result.data as Map<String, dynamic>?;
      if (data != null) {
        ref.read(profileProvider.notifier).fillFromCv(data);
        final p = ref.read(profileProvider);
        _name.text = p.fullName;
        _email.text = p.email;
        _phone.text = p.phone;
        _location.text = p.location;
        _summary.text = p.summary;
        _skills.text = p.skills.join(', ');
        _exp.text = p.experience;
        _edu.text = p.education;
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CV parsed — review and save')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CV parse failed: $e')));
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final skills = _skills.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    ref.read(profileProvider.notifier).update(ref.read(profileProvider).copyWith(
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          location: _location.text.trim(),
          summary: _summary.text.trim(),
          skills: skills,
          experience: _exp.text.trim(),
          education: _edu.text.trim(),
          prefType: _prefType,
        ));
    await ref.read(profileProvider.notifier).save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
      context.go('/jobs');
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your profile'), actions: [
        TextButton(onPressed: () => context.go('/jobs'), child: const Text('Skip')),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE4E4E7)), borderRadius: BorderRadius.circular(8)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Upload CV', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('PDF only. We extract and prefill — you edit.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF71717A))),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _parsing ? null : _pickCv, icon: _parsing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file, size: 18), label: Text(_parsing ? 'Parsing' : 'Choose PDF')),
            ]),
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 12),
          TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location (e.g. Jakarta, Indonesia)')),
          const SizedBox(height: 12),
          TextField(controller: _summary, decoration: const InputDecoration(labelText: 'Summary'), maxLines: 3),
          const SizedBox(height: 12),
          TextField(controller: _skills, decoration: const InputDecoration(labelText: 'Skills (comma separated)', hintText: 'Flutter, Dart, SQL')),
          const SizedBox(height: 12),
          TextField(controller: _exp, decoration: const InputDecoration(labelText: 'Experience'), maxLines: 3),
          const SizedBox(height: 12),
          TextField(controller: _edu, decoration: const InputDecoration(labelText: 'Education'), maxLines: 2),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _prefType,
            decoration: const InputDecoration(labelText: 'Preferred type'),
            items: const ['Any', 'WFO', 'Remote', 'Hybrid'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => setState(() => _prefType = v ?? 'Any'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving' : 'Save and see jobs')),
        ],
      ),
    );
  }
}
