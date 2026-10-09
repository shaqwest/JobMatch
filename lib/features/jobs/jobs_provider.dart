import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../core/supabase.dart';
import '../profile/profile_provider.dart';
import 'job_filter.dart';
import 'job_model.dart';

class JobsState {
  final List<Job> jobs;
  final List<Job> visible;
  final bool loading;
  final int page;
  final bool hasMore;
  final JobFilters filters;

  const JobsState({
    this.jobs = const [],
    this.visible = const [],
    this.loading = false,
    this.page = 0,
    this.hasMore = true,
    this.filters = const JobFilters(),
  });

  JobsState copyWith({
    List<Job>? jobs,
    List<Job>? visible,
    bool? loading,
    int? page,
    bool? hasMore,
    JobFilters? filters,
  }) =>
      JobsState(
        jobs: jobs ?? this.jobs,
        visible: visible ?? this.visible,
        loading: loading ?? this.loading,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        filters: filters ?? this.filters,
      );
}

double _tfidfScore(Job job, List<String> skills) {
  if (skills.isEmpty) return job.matchScore;
  final text = '${job.title} ${job.description} ${job.responsibilities ?? ''}'.toLowerCase();
  var hits = 0;
  for (final s in skills) {
    if (s.trim().isEmpty) continue;
    if (text.contains(s.toLowerCase())) hits++;
  }
  return (hits / skills.length * 100).clamp(0, 100).toDouble();
}

List<Job> _applyFilters(List<Job> jobs, JobFilters f) {
  var out = jobs.where((j) {
    if (f.types.isNotEmpty && !f.types.contains(j.type)) return false;
    if (f.salaryMin != null && (j.salaryMax ?? j.salaryMin ?? 0) < f.salaryMin!) return false;
    if (f.salaryMax != null && (j.salaryMin ?? j.salaryMax ?? 999999999) > f.salaryMax!) return false;
    return true;
  }).toList();
  out.sort((a, b) {
    int cmp;
    switch (f.sortField) {
      case SortField.match:
        cmp = a.matchScore.compareTo(b.matchScore);
        break;
      case SortField.salary:
        cmp = (a.salaryMin ?? 0).compareTo(b.salaryMin ?? 0);
        break;
      case SortField.postedAt:
        cmp = a.postedAt.compareTo(b.postedAt);
        break;
    }
    return f.sortOrder == SortOrder.asc ? cmp : -cmp;
  });
  return out;
}

class JobsNotifier extends StateNotifier<JobsState> {
  final Ref ref;
  JobsNotifier(this.ref) : super(const JobsState()) {
    load();
  }

  Future<void> load({bool refresh = false}) async {
    if (state.loading) return;
    state = state.copyWith(loading: true);
    try {
      List<Job> fetched = [];
      final c = supabaseOrNull;
      if (c != null && isSupabaseConfigured) {
        try {
          final rows = await c.from('jobs').select().order('posted_at', ascending: false).limit(200);
          fetched = (rows as List).map((e) => Job.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {
          fetched = mockJobs();
        }
      } else {
        await Future.delayed(const Duration(milliseconds: 900));
        fetched = mockJobs();
      }
      final skills = ref.read(profileProvider).skills;
      if (skills.isNotEmpty) {
        fetched = fetched.map((j) => j.copyWithMatch(_tfidfScore(j, skills))).toList();
      }
      final filtered = _applyFilters(fetched, state.filters);
      final page = refresh ? 0 : state.page;
      final visible = filtered.take((page + 1) * jobsPageSize).toList();
      state = state.copyWith(
        jobs: fetched,
        visible: visible,
        page: page,
        hasMore: visible.length < filtered.length,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  void setFilters(JobFilters f) {
    final filtered = _applyFilters(state.jobs, f);
    state = state.copyWith(
      filters: f,
      page: 0,
      visible: filtered.take(jobsPageSize).toList(),
      hasMore: filtered.length > jobsPageSize,
    );
  }

  void nextPage() {
    if (!state.hasMore || state.loading) return;
    final filtered = _applyFilters(state.jobs, state.filters);
    final next = state.page + 1;
    final visible = filtered.take((next + 1) * jobsPageSize).toList();
    state = state.copyWith(page: next, visible: visible, hasMore: visible.length < filtered.length);
  }

  Future<void> refresh() => load(refresh: true);
}

final jobsProvider = StateNotifierProvider<JobsNotifier, JobsState>((ref) => JobsNotifier(ref));
