import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase.dart';
import '../../widgets/timeline_item.dart';
import 'profile_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _parsing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pickCv() async {
    setState(() => _parsing = true);
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf'], withData: true);
      if (res == null || res.files.isEmpty) return;
      final bytes = res.files.single.bytes;
      if (bytes == null) return;
      if (!isSupabaseConfigured) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo: CV parsed locally.')));
        return;
      }
      final fileName = res.files.single.name;
      final user = supabaseOrNull!.auth.currentUser;
      if (user == null) return;
      final storagePath = '${user.id}/$fileName';
      await supabaseOrNull!.storage.from('cv_pdfs').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(contentType: 'application/pdf', upsert: true),
      );
      final result = await supabaseOrNull!.functions.invoke('cv-parse', body: {'path': storagePath});
      if (result.data != null && result.data is Map) {
        await ref.read(profileProvider.notifier).reload();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated from CV')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
              onPressed: () => context.go('/jobs'),
            ),
            title: const Text('My Profile', style: TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600)),
            actions: [
              IconButton(
                icon: const Icon(Icons.upload_file, color: Color(0xFF2563EB)),
                tooltip: 'Upload CV',
                onPressed: _parsing ? null : _pickCv,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(Icons.person, size: 40, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    profile.fullName.isEmpty ? 'Your Name' : profile.fullName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.headline.isEmpty ? 'Mobile Developer | Flutter' : profile.headline,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(profile.location.isEmpty ? 'Location' : profile.location, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                      const SizedBox(width: 16),
                      const Icon(Icons.email_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(profile.email.isEmpty ? 'email@domain.com' : profile.email, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Verification Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.auto_awesome, size: 14, color: Color(0xFF166534)),
                        SizedBox(width: 6),
                        Text(
                          'Profile auto-generated from CV',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF2563EB),
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: const Color(0xFF2563EB),
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Experience'),
                  Tab(text: 'Skills'),
                  Tab(text: 'Education'),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Experience Tab
                profile.experience.isEmpty
                    ? const Center(child: Text('No experience listed. Upload your CV to populate.', style: TextStyle(color: Color(0xFF64748B))))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 24),
                        itemCount: profile.experience.length,
                        itemBuilder: (context, index) {
                          return TimelineItem(
                            experience: profile.experience[index],
                            isLast: index == profile.experience.length - 1,
                          );
                        },
                      ),
                // Skills Tab
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: profile.skills.isEmpty
                      ? const Center(child: Text('No skills listed.', style: TextStyle(color: Color(0xFF64748B))))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: profile.skills.map((s) => Chip(
                                label: Text(s),
                                backgroundColor: Colors.white,
                                labelStyle: const TextStyle(color: Color(0xFF1E293B)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: Color(0xFFE2E8F0))),
                              )).toList(),
                        ),
                ),
                // Education Tab
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(profile.education.isEmpty ? 'No education listed.' : profile.education, style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}
