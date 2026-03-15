import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService dbService = FirestoreService();
    final User? user = authService.currentUser;

    // Zen Colors
    const Color backgroundColor = Color(0xFF121212);
    const Color cardColor = Color(0xFF1E1E1E);
    const Color accentColor = Color(0xFFD0BCFF);
    const TextStyle textStyle = TextStyle(color: Colors.white, fontFamily: 'Roboto');

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Profile", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w300)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: dbService.getUserProfileStream(),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                CircleAvatar(
                  radius: 50,
                  backgroundColor: accentColor.withOpacity(0.1),
                  child: Text(
                    (user?.displayName ?? profile?.username ?? "U")[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, color: accentColor, fontWeight: FontWeight.w200),
                  ),
                ),
                const SizedBox(height: 24),
                
                // User Details
                Text(
                  user?.displayName ?? profile?.username ?? "Anonymous",
                  style: textStyle.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    user!.email!,
                    style: textStyle.copyWith(fontSize: 14, color: Colors.white60),
                  ),
                ],
                if (profile?.username != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: profile!.username!));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("ID copied!", style: TextStyle(color: Colors.black)),
                            backgroundColor: accentColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "ID: ${profile!.username}",
                        style: const TextStyle(fontSize: 12, color: accentColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 40),
                
                // Stats Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat("Subscribed", profile?.subscribedCollections.length ?? 0),
                      Container(height: 30, width: 1, color: Colors.white10),
                      _buildStat("Favorites", profile?.favoriteCollectionIds.length ?? 0),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Actions
                _buildActionTile(
                  icon: Icons.code_rounded,
                  title: "GitHub / kemaltombul",
                  onTap: () async {
                    final Uri url = Uri.parse('https://github.com/kemaltombul');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.alternate_email_rounded,
                  title: "Contact Developer",
                  onTap: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'kemaltombull@hotmail.com',// replace with real email if known or keep generic
                      query: encodeQueryParameters(<String, String>{
                        'subject': 'English Flashcards Feedback',
                      }),
                    );
                    if (await canLaunchUrl(emailLaunchUri)) {
                      await launchUrl(emailLaunchUri);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.logout_rounded,
                  title: "Logout",
                  color: Colors.redAccent,
                  onTap: () async {
                    bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: cardColor,
                        title: const Text("Logout", style: TextStyle(color: Colors.white)),
                        content: const Text("Are you sure you want to log out?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Logout", style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      authService.signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.white70,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w400),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.3), size: 14),
            ],
          ),
        ),
      ),
    );
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((MapEntry<String, String> e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
