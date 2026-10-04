import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/page_transitions.dart';
import '../widgets/settings_widgets.dart';
import 'personal_info_page.dart';
import 'notification_settings_page.dart';
import 'location_settings_page.dart';
import 'visited_cafes_page.dart';
import 'collections_page.dart';
import 'coffee_preferences_page.dart';

/// Coffee Explorer's Account Settings hub — same dark menu look as the
/// Profile tab, with each row opening its own settings screen.
class AccountSettingsPage extends StatelessWidget {
  const AccountSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    void open(Widget page) => Navigator.push(context, slideFadeRoute(page));

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Account Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                children: [
                  const _GroupLabel('Account'),
                  ProfileMenuTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Personal Information',
                    onTap: () => open(const PersonalInfoPage()),
                  ),
                  ProfileMenuTile(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notifications',
                    onTap: () => open(const NotificationSettingsPage()),
                  ),
                  ProfileMenuTile(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    onTap: () => open(const LocationSettingsPage()),
                  ),
                  const SizedBox(height: 12),
                  const _GroupLabel('Your Cafés'),
                  ProfileMenuTile(
                    icon: Icons.history_rounded,
                    label: 'Visited Cafés',
                    onTap: () => open(const VisitedCafesPage()),
                  ),
                  ProfileMenuTile(
                    icon: Icons.bookmarks_outlined,
                    label: 'My Collections',
                    onTap: () => open(const CollectionsPage()),
                  ),
                  ProfileMenuTile(
                    icon: Icons.coffee_outlined,
                    label: 'Coffee Preferences',
                    onTap: () => open(const CoffeePreferencesPage()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;

  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
      ),
    );
  }
}
