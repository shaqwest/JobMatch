import 'package:flutter_test/flutter_test.dart';
import 'package:jobmatch/features/jobs/job_model.dart';
import 'package:jobmatch/features/profile/profile_model.dart';

void main() {
  test('Job.fromJson parses fields and formats salaryLabel cleanly', () {
    final job = Job.fromJson({
      'id': 'job-1',
      'title': 'Flutter Engineer',
      'company': 'GoTo',
      'location': 'Jakarta',
      'type': 'Hybrid',
      'employment': 'full_time',
      'salary_min': 12000000,
      'salary_max': 18000000,
      'posted_at': '2026-11-22T10:00:00Z',
      'source': 'arbeitnow',
      'description': 'Build mobile features in Dart and Flutter.',
      'apply_url': 'https://example.com/jobs/1',
    });

    expect(job.title, 'Flutter Engineer');
    expect(job.salaryLabel, 'Rp 12000000 - 18000000');

    final undisclosed = Job.fromJson({
      'id': 'job-2',
      'title': 'QA Engineer',
      'company': 'Traveloka',
      'location': 'Remote',
      'posted_at': '2026-11-22T10:00:00Z',
      'description': 'Automated testing.',
      'apply_url': 'https://example.com/jobs/2',
    });
    expect(undisclosed.salaryLabel, 'Not disclosed');
  });

  test('Profile.fromJson handles structured experience list', () {
    final profile = Profile.fromJson({
      'full_name': 'Budi Santoso',
      'email': 'budi@example.com',
      'headline': 'QA Engineer | Software Developer',
      'skills': ['Dart', 'Flutter', 'PostgreSQL'],
      'experience': [
        {
          'id': 1,
          'company': 'TechCorp',
          'title': 'QA Engineer',
          'duration': '2025 - Present',
          'points': ['Automated E2E test suites'],
          'is_current': true,
        }
      ],
    });

    expect(profile.fullName, 'Budi Santoso');
    expect(profile.skills.length, 3);
    expect(profile.experience.first.id, '1');
    expect(profile.experience.first.isCurrent, isTrue);
  });
}