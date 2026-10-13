import 'package:flutter/material.dart';
import '../features/profile/profile_model.dart';

class TimelineItem extends StatelessWidget {
  final Experience experience;
  final bool isLast;

  const TimelineItem({
    super.key,
    required this.experience,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline Line
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: experience.isCurrent ? const Color(0xFF2563EB) : Colors.white,
                  border: Border.all(
                    color: const Color(0xFF2563EB),
                    width: 3,
                  ),
                ),
                child: experience.isCurrent
                    ? null
                    : Container(
                        margin: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 120,
                  color: const Color(0xFFE5E7EB),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(experience.title,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B))),
                      const Icon(Icons.edit, size: 14, color: Color(0xFF64748B)),
                    ],
                  ),
                  Text(experience.company,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB))),
                  const SizedBox(height: 4),
                  Text(experience.duration,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: experience.points
                          .map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $p',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF334155),
                                        height: 1.5)),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
