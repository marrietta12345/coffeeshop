import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/notification_settings.dart';
import '../utils/user_profile_service.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/top_banner.dart';

/// Four simple on/off notification choices, saved instantly to
/// `users/{uid}.notificationSettings` whenever a switch is flipped.
class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  Future<void> _set(BuildContext context, String key, bool value) async {
    try {
      await UserProfileService.update({
        'notificationSettings': {key: value},
      });
    } catch (_) {
      if (!context.mounted) return;
      showTopBanner(context, "Couldn't save that setting. Please try again.", isSuccess: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Notifications',
      child: StreamBuilder<Map<String, dynamic>>(
        stream: UserProfileService.profileStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown));
          }
          final settings = NotificationSettings.fromMap(
            snapshot.data!['notificationSettings'] as Map<String, dynamic>?,
          );

          return ListView(
            children: [
              const Text(
                'Choose what Kafelo can notify you about.',
                style: TextStyle(fontSize: 13, color: AppColors.textGrey),
              ),
              const SizedBox(height: 16),
              SettingsSwitchTile(
                icon: Icons.near_me_outlined,
                title: 'Nearby recommendations',
                subtitle: 'Coffee shops worth trying near you',
                value: settings.nearbyRecommendations,
                onChanged: (v) => _set(context, NotificationSettings.nearbyRecommendationsKey, v),
              ),
              SettingsSwitchTile(
                icon: Icons.favorite_border_rounded,
                title: 'Updates from favorite cafés',
                subtitle: 'New menu items, hours and news from cafés you saved',
                value: settings.favoriteUpdates,
                onChanged: (v) => _set(context, NotificationSettings.favoriteUpdatesKey, v),
              ),
              SettingsSwitchTile(
                icon: Icons.storefront_outlined,
                title: 'New café discoveries',
                subtitle: 'When new coffee shops join Kafelo',
                value: settings.newDiscoveries,
                onChanged: (v) => _set(context, NotificationSettings.newDiscoveriesKey, v),
              ),
              SettingsSwitchTile(
                icon: Icons.notifications_none_rounded,
                title: 'General notifications',
                subtitle: 'App updates and announcements',
                value: settings.general,
                onChanged: (v) => _set(context, NotificationSettings.generalKey, v),
              ),
            ],
          );
        },
      ),
    );
  }
}
