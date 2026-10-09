import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFF4F4F5),
      highlightColor: const Color(0xFFFFFFFF),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE4E4E7)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 14, width: 180, color: Colors.white),
            const SizedBox(height: 8),
            Container(height: 12, width: 120, color: Colors.white),
            const SizedBox(height: 16),
            Row(children: [
              Container(height: 22, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999))),
              const SizedBox(width: 8),
              Container(height: 22, width: 70, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999))),
            ]),
            const SizedBox(height: 12),
            Container(height: 10, width: double.infinity, color: Colors.white),
            const SizedBox(height: 6),
            Container(height: 10, width: 200, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 5});
  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const ShimmerCard(),
    );
  }
}
