import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/settings_widgets.dart';
import 'welcome_page.dart';
import 'saved_shops_page.dart';
import 'account_settings_page.dart';
import 'visited_cafes_page.dart';
import 'my_reviews_page.dart';

/// Profile tab content. Plain widget (no Scaffold/bottom nav of its own)
/// — MainNavPage supplies those, which is what makes Explore <-> You
/// actually work both ways.
class YouPage extends StatelessWidget {
  const YouPage({super.key});

  void _openAccountSettings(BuildContext context) {
    Navigator.push(context, slideFadeRoute(const AccountSettingsPage()));
  }

  @override
  Widget build(BuildContext context) {
    // userChanges() re-emits after a name/photo edit in Personal
    // Information, so the header updates without a restart.
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) => _buildProfile(context, snapshot.data),
    );
  }

  Widget _buildProfile(BuildContext context, User? user) {
    final name = (user?.displayName?.isNotEmpty ?? false)
        ? user!.displayName!
        : 'Coffee Lover';
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

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
                    backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                    child: hasPhoto ? null : const Icon(Icons.person_rounded, color: AppColors.primaryBrown, size: 32),
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
              ProfileMenuTile(
                icon: Icons.local_cafe_outlined,
                label: 'Visited Cafés',
                onTap: () => Navigator.push(context, slideFadeRoute(const VisitedCafesPage())),
              ),
              ProfileMenuTile(
                icon: Icons.favorite_border_rounded,
                label: 'My Favorites',
                onTap: () => Navigator.push(context, slideUpRoute(const SavedShopsPage())),
              ),
              ProfileMenuTile(
                icon: Icons.rate_review_outlined,
                label: 'My Reviews',
                onTap: () => Navigator.push(context, slideFadeRoute(const MyReviewsPage())),
              ),
              ProfileMenuTile(
                icon: Icons.settings_outlined,
                label: 'Account Settings',
                onTap: () => _openAccountSettings(context),
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
