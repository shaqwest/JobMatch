import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/auth_gate.dart';
import '../features/auth/login_page.dart';
import '../features/profile/profile_page.dart';
import '../features/jobs/jobs_page.dart';
import '../features/jobs/job_detail_page.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const AuthGate()),
    GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
    GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
    GoRoute(path: '/jobs', builder: (_, __) => const JobsPage()),
    GoRoute(
      path: '/jobs/:id',
      builder: (ctx, state) {
        final id = state.pathParameters['id']!;
        final extra = state.extra as Map<String, dynamic>?;
        return JobDetailPage(jobId: id, job: extra);
      },
    ),
  ],
  errorBuilder: (_, s) => Scaffold(body: Center(child: Text(s.error.toString()))),
);
