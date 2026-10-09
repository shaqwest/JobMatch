class Profile {
  final String fullName;
  final String email;
  final String phone;
  final String location;
  final String summary;
  final List<String> skills;
  final String experience;
  final String education;
  final String prefType;
  final String prefLocation;

  const Profile({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.location = '',
    this.summary = '',
    this.skills = const [],
    this.experience = '',
    this.education = '',
    this.prefType = 'Any',
    this.prefLocation = '',
  });

  Profile copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? location,
    String? summary,
    List<String>? skills,
    String? experience,
    String? education,
    String? prefType,
    String? prefLocation,
  }) =>
      Profile(
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        location: location ?? this.location,
        summary: summary ?? this.summary,
        skills: skills ?? this.skills,
        experience: experience ?? this.experience,
        education: education ?? this.education,
        prefType: prefType ?? this.prefType,
        prefLocation: prefLocation ?? this.prefLocation,
      );

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'location': location,
        'summary': summary,
        'skills': skills,
        'experience': experience,
        'education': education,
        'pref_type': prefType,
        'pref_location': prefLocation,
      };

  static Profile fromJson(Map<String, dynamic> j) => Profile(
        fullName: j['full_name'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        location: j['location'] ?? '',
        summary: j['summary'] ?? '',
        skills: List<String>.from(j['skills'] ?? []),
        experience: j['experience'] ?? '',
        education: j['education'] ?? '',
        prefType: j['pref_type'] ?? 'Any',
        prefLocation: j['pref_location'] ?? '',
      );
}
