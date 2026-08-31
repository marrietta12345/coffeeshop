import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/top_banner.dart';
import 'welcome_page.dart';
import 'saved_shops_page.dart';

/// Profile tab content. Plain widget (no Scaffold/bottom nav of its own)
/// — MainNavPage supplies those, which is what makes Explore <-> You
/// actually work both ways.
class YouPage extends StatelessWidget {
  const YouPage({super.key});

  void _openAccountSettings(BuildContext context) {
    // TODO: build a real Account Settings page (name, email, password,
    // notification preferences, etc.) once that scope is defined.
    showTopBanner(context, 'Account Settings coming soon!', isSuccess: true);
  }

  void _showAboutApp(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Kafelo',
      applicationVersion: '1.0.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset('lib/images/kafelo_logo.png', width: 48, height: 48),
      ),
      children: const [
        SizedBox(height: 12),
        Text(
          'Kafelo helps you discover and explore local coffee shops around Butuan City — '
          'browse menus, read reviews, and find your next favorite cup.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : 'Coffee Lover';
    final email = user?.email ?? '';

    return Container(
      color: AppColors.darkBackground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Profile',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () => _openAccountSettings(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                      child: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primaryBrown.withOpacity(0.2),
                    child: const Icon(Icons.person_rounded, color: AppColors.primaryBrown, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _MenuTile(
                icon: Icons.favorite_border_rounded,
                label: 'My Favorites',
                onTap: () => Navigator.push(context, slideUpRoute(const SavedShopsPage())),
              ),
              const _MenuTile(icon: Icons.rate_review_outlined, label: 'My Reviews'),
              _MenuTile(
                icon: Icons.settings_outlined,
                label: 'Account Settings',
                onTap: () => _openAccountSettings(context),
              ),
              _MenuTile(
                icon: Icons.info_outline_rounded,
                label: 'About the App',
                onTap: () => _showAboutApp(context),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFDEBEA),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      slideFadeRoute(const WelcomePage()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFD64545), size: 18),
                  label: const Text(
                    'Logout',
                    style: TextStyle(color: Color(0xFFD64545), fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MenuTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryBrown, size: 20),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}