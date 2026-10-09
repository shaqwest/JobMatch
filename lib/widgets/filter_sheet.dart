import 'package:flutter/material.dart';
import '../features/jobs/job_filter.dart';

class FilterSheet extends StatefulWidget {
  final JobFilters initial;
  final ValueChanged<JobFilters> onApply;
  const FilterSheet({super.key, required this.initial, required this.onApply});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late JobFilters f = widget.initial;
  late RangeValues salary = RangeValues(
    (f.salaryMin ?? 0).toDouble(),
    (f.salaryMax ?? 50000000).toDouble(),
  );
  bool salaryActive = false;

  @override
  void initState() {
    super.initState();
    salaryActive = f.salaryMin != null || f.salaryMax != null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('Filters', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(onPressed: () => widget.onApply(const JobFilters()), child: const Text('Reset')),
              ]),
              const SizedBox(height: 12),
              Text('Type', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['WFO', 'Remote', 'Hybrid'].map((t) {
                  final sel = f.types.contains(t);
                  return FilterChip(
                    label: Text(t),
                    selected: sel,
                    onSelected: (v) {
                      final s = Set<String>.from(f.types);
                      if (v) s.add(t); else s.remove(t);
                      setState(() => f = f.copyWith(types: s));
                    },
                    selectedColor: const Color(0xFFEFF6FF),
                    checkmarkColor: const Color(0xFF2563EB),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Text('Salary range', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(value: salaryActive, onChanged: (v) => setState(() => salaryActive = v)),
              ]),
              if (salaryActive) ...[
                RangeSlider(
                  min: 0,
                  max: 50000000,
                  divisions: 50,
                  labels: RangeLabels('${(salary.start / 1000000).toStringAsFixed(0)}M', '${(salary.end / 1000000).toStringAsFixed(0)}M'),
                  values: salary,
                  onChanged: (v) => setState(() => salary = v),
                ),
                Text('Rp ${salary.start.toInt()} - Rp ${salary.end.toInt()}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF71717A))),
              ],
              const SizedBox(height: 16),
              Text('Sort', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('Match'), selected: f.sortField == SortField.match, onSelected: (_) => setState(() => f = f.copyWith(sortField: SortField.match))),
                ChoiceChip(label: const Text('Salary'), selected: f.sortField == SortField.salary, onSelected: (_) => setState(() => f = f.copyWith(sortField: SortField.salary))),
                ChoiceChip(label: const Text('Newest'), selected: f.sortField == SortField.postedAt && f.sortOrder == SortOrder.desc, onSelected: (_) => setState(() => f = f.copyWith(sortField: SortField.postedAt, sortOrder: SortOrder.desc))),
                ChoiceChip(label: const Text('Oldest'), selected: f.sortField == SortField.postedAt && f.sortOrder == SortOrder.asc, onSelected: (_) => setState(() => f = f.copyWith(sortField: SortField.postedAt, sortOrder: SortOrder.asc))),
              ]),
              const SizedBox(height: 8),
              if (f.sortField != SortField.postedAt)
                Wrap(spacing: 8, children: [
                  ChoiceChip(label: const Text('Ascending'), selected: f.sortOrder == SortOrder.asc, onSelected: (_) => setState(() => f = f.copyWith(sortOrder: SortOrder.asc))),
                  ChoiceChip(label: const Text('Descending'), selected: f.sortOrder == SortOrder.desc, onSelected: (_) => setState(() => f = f.copyWith(sortOrder: SortOrder.desc))),
                ]),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    var next = f;
                    if (salaryActive) {
                      next = next.copyWith(salaryMin: salary.start.toInt(), salaryMax: salary.end.toInt());
                    } else {
                      next = next.copyWith(clearSalary: true);
                    }
                    widget.onApply(next);
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
