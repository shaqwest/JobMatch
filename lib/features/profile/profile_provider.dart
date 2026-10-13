import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/supabase.dart';
import 'profile_model.dart';

class ProfileNotifier extends StateNotifier<Profile> {
  ProfileNotifier() : super(const Profile()) {
    _load();
  }

  Future<void> _load() async {
    final c = supabaseOrNull;
    if (c == null) return;
    final user = c.auth.currentUser;
    if (user == null) return;
    try {
      final row = await c.from('profiles').select().eq('id', user.id).maybeSingle();
      if (row != null) {
        state = Profile.fromJson(row);
      }
    } catch (_) {}
  }

  Future<void> reload() async {
    await _load();
  }

  void update(Profile p) => state = p;

  Future<void> save() async {
    final c = supabaseOrNull;
    if (c == null) return;
    final user = c.auth.currentUser;
    if (user == null) return;
    await c.from('profiles').upsert({'id': user.id, ...state.toJson()});
  }

  void fillFromCv(Map<String, dynamic> json) {
    final expRaw = json['experience'];
    List<Experience>? parsedExp;
    if (expRaw is List) {
      parsedExp = expRaw.map((e) {
        if (e is String) return Experience(id: DateTime.now().millisecondsSinceEpoch.toString(), title: e, company: '', duration: '', points: []);
        return Experience.fromJson(Map<String, dynamic>.from(e as Map));
      }).toList();
    }
    state = state.copyWith(
      fullName: json['full_name'] ?? state.fullName,
      email: json['email'] ?? state.email,
      phone: json['phone'] ?? state.phone,
      location: json['location'] ?? state.location,
      headline: json['headline'] ?? state.headline,
      summary: json['summary'] ?? state.summary,
      skills: json['skills'] != null ? List<String>.from(json['skills']) : state.skills,
      experience: parsedExp ?? state.experience,
      education: json['education'] ?? state.education,
    );
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, Profile>((_) => ProfileNotifier());
