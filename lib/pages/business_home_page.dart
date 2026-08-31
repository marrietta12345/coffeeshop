import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import 'welcome_page.dart';

/// Placeholder landing page for Coffee Shop Owner accounts. The real
/// dashboard (shop profile editing, menu management, orders, etc.) isn't
/// built yet — this exists so a successful owner sign-in has somewhere
/// real to land instead of a dead end.
class BusinessHomePage extends StatelessWidget {
  const BusinessHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.isNotEmpty ?? false) ? user!.displayName! : 'there';

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Shop Dashboard',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome, $name!',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const Spacer(),
              Icon(Icons.storefront_rounded, color: AppColors.primaryBrown.withOpacity(0.4), size: 72),
              const SizedBox(height: 16),
              const Text(
                'Your shop dashboard is coming soon',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                "You're signed in as a Coffee Shop Owner. Menu management, "
                "shop profile editing, and order tracking will live here.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.5),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryBrown),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      slideFadeRoute(const WelcomePage()),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(color: AppColors.primaryBrown, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}