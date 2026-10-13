class Experience {
  final String id;
  final String company;
  final String title;
  final String duration;
  final List<String> points;
  final bool isCurrent;

  const Experience({
    required this.id,
    required this.company,
    required this.title,
    required this.duration,
    required this.points,
    this.isCurrent = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'company': company,
        'title': title,
        'duration': duration,
        'points': points,
        'is_current': isCurrent,
      };

  static Experience fromJson(Map<String, dynamic> j) => Experience(
        id: j['id'] ?? '',
        company: j['company'] ?? '',
        title: j['title'] ?? '',
        duration: j['duration'] ?? '',
        points: List<String>.from(j['points'] ?? []),
        isCurrent: j['is_current'] ?? false,
      );
}

class Profile {
  final String fullName;
  final String email;
  final String phone;
  final String location;
  final String headline;
  final String summary;
  final List<String> skills;
  final List<Experience> experience;
  final String education;
  final String prefType;

  const Profile({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.headline = '',
    this.summary = '',
    this.skills = const [],
    this.experience = const [],
    this.education = '',
    this.prefType = 'Any',
  });

  Profile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? location,
    String? headline,
    String? summary,
    List<String>? skills,
    List<Experience>? experience,
    String? education,
    String? prefType,
  }) =>
      Profile(
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        location: location ?? this.location,
        headline: headline ?? this.headline,
        summary: summary ?? this.summary,
        skills: skills ?? this.skills,
        experience: experience ?? this.experience,
        education: education ?? this.education,
        prefType: prefType ?? this.prefType,
      );

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'location': location,
        'headline': headline,
        'summary': summary,
        'skills': skills,
        'experience': experience.isEmpty ? '' : experience.map((e) => '${e.title} at ${e.company}'.trim()).join('\n'),
        'education': education,
        'pref_type': prefType,
        'cv_parsed': {
          'full_name': fullName,
          'headline': headline,
          'email': email,
          'phone': phone,
          'location': location,
          'summary': summary,
          'skills': skills,
          'experience': experience.map((e) => e.toJson()).toList(),
          'education': education,
        },
      };

  static Profile fromJson(Map<String, dynamic> j) {
    final p = j['cv_parsed'] is Map ? (j['cv_parsed'] as Map<String, dynamic>) : j;
    final rawExp = p['experience'] ?? j['experience'];
    List<Experience> exps = [];
    if (rawExp is List) {
      exps = rawExp.map((e) {
        if (e is String) return Experience(id: e.hashCode.toString(), title: e, company: '', duration: '', points: []);
        if (e is Map) return Experience.fromJson(Map<String, dynamic>.from(e));
        return null;
      }).whereType<Experience>().toList();
    } else if (rawExp is String && rawExp.trim().isNotEmpty) {
      exps = [Experience(id: '1', title: rawExp, company: '', duration: '', points: [])];
    }
    return Profile(
      fullName: p['full_name'] ?? j['full_name'] ?? '',
      email: p['email'] ?? j['email'] ?? '',
      phone: p['phone'] ?? j['phone'] ?? '',
      location: p['location'] ?? j['location'] ?? '',
      headline: p['headline'] ?? j['headline'] ?? j['summary'] ?? '',
      summary: p['summary'] ?? j['summary'] ?? '',
      skills: List<String>.from(p['skills'] ?? j['skills'] ?? []),
      experience: exps,
      education: p['education'] ?? j['education'] ?? '',
      prefType: j['pref_type'] ?? 'Any',
    );
  }
}
