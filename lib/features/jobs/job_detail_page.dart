import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'job_model.dart';

class JobDetailPage extends StatelessWidget {
  final String jobId;
  final Map<String, dynamic>? job;
  const JobDetailPage({super.key, required this.jobId, this.job});

  Job _resolve() {
    if (job != null) return Job.fromJson(job!);
    return mockJobs().firstWhere((e) => e.id == jobId, orElse: () => mockJobs().first);
  }

  @override
  Widget build(BuildContext context) {
    final j = _resolve();
    final date = DateFormat('dd MMM yyyy, HH:mm').format(j.postedAtJakarta);
    final relative = _relative(j.postedAt);
    return Scaffold(
      appBar: AppBar(title: Text(j.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          Text(j.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${j.company} · ${j.location}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF71717A))),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _chip(j.type),
            _chip(j.employment.replaceAll('_', ' ')),
            if (j.contractDuration != null) _chip(j.contractDuration!),
            _chip(j.workload ?? 'Not disclosed'),
            _chip(j.salaryLabel),
          ]),
          const SizedBox(height: 16),
          _section(context, 'Company', Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(j.company, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (j.website != null) ...[
              const SizedBox(height: 4),
              InkWell(
                onTap: () => launchUrl(Uri.parse(j.website!), mode: LaunchMode.externalApplication),
                child: Text(j.website!, style: const TextStyle(color: Color(0xFF2563EB), fontSize: 13)),
              ),
            ],
            if (j.rating != null) ...[
              const SizedBox(height: 6),
              Text('Rating: ${j.rating} / 5', style: Theme.of(context).textTheme.bodySmall),
            ],
          ])),
          _section(context, 'Posted', Text('$relative · $date WIB (Asia/Jakarta)', style: Theme.of(context).textTheme.bodySmall)),
          _section(context, 'Description', Text(j.description, style: Theme.of(context).textTheme.bodyMedium)),
          _section(context, 'Responsibilities', Text(j.responsibilities ?? 'Not disclosed', style: Theme.of(context).textTheme.bodyMedium)),
          _section(context, 'Benefits', Text(j.benefits ?? 'Not disclosed', style: Theme.of(context).textTheme.bodyMedium)),
          _section(context, 'Source', Text(j.source, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF71717A)))),
        ],
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE4E4E7)))),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => launchUrl(Uri.parse(j.applyUrl), mode: LaunchMode.externalApplication),
            child: const Text('Apply on company site'),
          ),
        ),
      ),
    );
  }

  Widget _chip(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF4F4F5), border: Border.all(color: const Color(0xFFE4E4E7)), borderRadius: BorderRadius.circular(999)),
        child: Text(s, style: const TextStyle(fontSize: 11, color: Color(0xFF27272A))),
      );

  Widget _section(BuildContext c, String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(c).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF27272A))),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE4E4E7)), borderRadius: BorderRadius.circular(8)),
            child: child,
          ),
        ]),
      );

  String _relative(DateTime t) {
    final d = DateTime.now().toUtc().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}
