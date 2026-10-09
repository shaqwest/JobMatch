import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/supabase.dart';
import '../../widgets/filter_sheet.dart';
import '../../widgets/job_card.dart';
import '../../widgets/shimmer_card.dart';
import 'jobs_provider.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) {
        ref.read(jobsProvider.notifier).nextPage();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(jobsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('JobMatch'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline, size: 20),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => FilterSheet(
                initial: state.filters,
                onApply: (f) => ref.read(jobsProvider.notifier).setFilters(f),
              ),
            ),
            icon: const Icon(Icons.tune, size: 20),
          ),
          if (isSupabaseConfigured)
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await supabaseOrNull!.auth.signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout, size: 18),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: state.loading && state.visible.isEmpty
          ? const ShimmerList()
          : RefreshIndicator(
              onRefresh: () => ref.read(jobsProvider.notifier).refresh(),
              child: state.visible.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 60),
                        Icon(Icons.search_off, size: 40, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text('No jobs match your filters', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        Text('Try adjusting salary or type, or refresh.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF71717A))),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: () => ref.read(jobsProvider.notifier).refresh(), child: const Text('Refresh')),
                      ],
                    )
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: state.visible.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        if (i >= state.visible.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                          );
                        }
                        final job = state.visible[i];
                        return JobCard(
                          job: job,
                          onTap: () => context.push('/jobs/${job.id}', extra: {
                            'title': job.title,
                            'company': job.company,
                            'website': job.website,
                            'location': job.location,
                            'type': job.type,
                            'employment': job.employment,
                            'contract_duration': job.contractDuration,
                            'salary_min': job.salaryMin,
                            'salary_max': job.salaryMax,
                            'posted_at': job.postedAt.toIso8601String(),
                            'source': job.source,
                            'description': job.description,
                            'responsibilities': job.responsibilities,
                            'benefits': job.benefits,
                            'workload': job.workload,
                            'apply_url': job.applyUrl,
                            'company_rating': job.rating,
                            'match_score': job.matchScore,
                            'id': job.id,
                          }),
                        );
                      },
                    ),
            ),
    );
  }
}
