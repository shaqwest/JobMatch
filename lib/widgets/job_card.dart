import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../features/jobs/job_model.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  const JobCard({super.key, required this.job, required this.onTap});

  Color _matchColor(double s) {
    if (s >= 85) return const Color(0xFF15803D);
    if (s >= 70) return const Color(0xFFA16207);
    return const Color(0xFF71717A);
  }

  String _matchLabel(double s) {
    if (s >= 85) return 'Highly matched';
    if (s >= 70) return 'Good match';
    if (s > 0) return 'Low match';
    return 'New';
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy, HH:mm').format(job.postedAtJakarta);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E4E7)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(job.title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${job.company} · ${job.location}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF71717A))),
                  ]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _matchColor(job.matchScore).withOpacity(0.08),
                    border: Border.all(color: _matchColor(job.matchScore).withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    job.matchScore > 0 ? '${job.matchScore.toStringAsFixed(0)}% ${_matchLabel(job.matchScore)}' : _matchLabel(0),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _matchColor(job.matchScore)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(job.type),
                _chip(job.employment.replaceAll('_', ' ')),
                if (job.contractDuration != null) _chip(job.contractDuration!),
                _chip(job.salaryLabel),
              ],
            ),
            const SizedBox(height: 10),
            Text(date, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF71717A))),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFF4F4F5), border: Border.all(color: const Color(0xFFE4E4E7)), borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF27272A))),
      );
}
