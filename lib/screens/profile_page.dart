import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _email    = 'kemaltombull@hotmail.com';
  static const _github   = 'https://github.com/kemaltombul';
  static const _linkedin = 'https://www.linkedin.com/in/kemal-tombul-802385200/';

  static const _bg     = Color(0xFF121212);
  static const _card   = Color(0xFF1E1E1E);
  static const _accent = Color(0xFFD0BCFF);
  static const _ts     = TextStyle(color: Colors.white, fontFamily: 'Roboto');

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _sendMail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      queryParameters: {'subject': 'True Vocab — Feedback'},
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final db   = FirestoreService();
    final user = auth.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: db.getUserProfileStream(),
        builder: (context, profileSnapshot) {
          final profile = profileSnapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Avatar ──────────────────────────────
                CircleAvatar(
                  radius: 50,
                  backgroundColor: _accent.withOpacity(0.1),
                  child: Text(
                    (user?.displayName ?? profile?.username ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                        fontSize: 40, color: _accent, fontWeight: FontWeight.w200),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  user?.displayName ?? profile?.username ?? 'Anonymous',
                  style: _ts.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 8),
                  Text(user!.email!,
                      style: _ts.copyWith(fontSize: 14, color: Colors.white60)),
                ],
                const SizedBox(height: 16),

                // ── Username pill ────────────────────────
                if (profile?.username != null)
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: profile!.username!));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('ID copied!',
                            style: TextStyle(color: Colors.black)),
                        backgroundColor: _accent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _accent.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.copy_rounded, size: 14, color: _accent),
                          const SizedBox(width: 8),
                          Text('@${profile!.username}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: _accent,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 40),

                // ── Stats ────────────────────────────────
                Row(children: [
                  Expanded(
                    child: StreamBuilder<int>(
                      stream: db.getUserStreakStream(),
                      builder: (ctx, s) => _statCard(
                        'Day Streak', s.data?.toString() ?? '0',
                        Icons.local_fire_department_rounded, Colors.orangeAccent),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _statCard(
                      'Cards Reviewed',
                      (profile?.totalCardsReviewed ?? 0).toString(),
                      Icons.style_rounded, _accent),
                  ),
                ]),
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  final ms      = profile?.totalStudyTimeMs ?? 0;
                  final hours   = (ms / 3600000).floor();
                  final minutes = ((ms % 3600000) / 60000).floor();
                  return _statCard(
                    'Total Study Time',
                    hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m',
                    Icons.timer_rounded, Colors.lightBlueAccent,
                    isFullWidth: true);
                }),

                const SizedBox(height: 48),

                // ── Actions ──────────────────────────────
                _actionTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout session',
                  color: Colors.redAccent,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: _card,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Text('Logout',
                            style: TextStyle(color: Colors.white)),
                        content: const Text('Are you sure you want to log out?',
                            style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel',
                                  style: TextStyle(color: Colors.white60))),
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Logout',
                                  style: TextStyle(color: Colors.redAccent))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      auth.signOut();
                      if (context.mounted) {
                        Navigator.of(context)
                            .pushNamedAndRemoveUntil('/', (r) => false);
                      }
                    }
                  },
                ),

                const SizedBox(height: 48),

                // ── Contact ──────────────────────────────
                _sectionLabel('Get in touch'),
                const SizedBox(height: 12),
                _contactTile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Send feedback',
                  subtitle: _email,
                  color: _accent,
                  onTap: _sendMail,
                ),
                const SizedBox(height: 10),
                _contactTile(
                  icon: Icons.code_rounded,
                  title: 'GitHub',
                  subtitle: 'github.com/kemaltombul',
                  color: Colors.white70,
                  onTap: () => _launch(_github),
                ),
                const SizedBox(height: 10),
                _contactTile(
                  icon: Icons.work_outline_rounded,
                  title: 'LinkedIn',
                  subtitle: 'kemal-tombul',
                  color: const Color(0xFF6B9FD4),
                  onTap: () => _launch(_linkedin),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String label) => Align(
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white38, fontSize: 12, letterSpacing: 1)),
      );

  Widget _statCard(String label, String value, IconData icon, Color color,
      {bool isFullWidth = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment:
            isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isFullWidth
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.white38)),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(title,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                color: color.withOpacity(0.3), size: 14),
          ]),
        ),
      ),
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color, fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        color: color.withOpacity(0.5), fontSize: 12)),
              ],
            ),
            const Spacer(),
            Icon(Icons.open_in_new_rounded,
                color: color.withOpacity(0.3), size: 14),
          ]),
        ),
      ),
    );
  }
}