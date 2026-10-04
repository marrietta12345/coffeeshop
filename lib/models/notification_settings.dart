/// A Coffee Explorer's notification choices, stored as a map under
/// `users/{uid}.notificationSettings`. Everything defaults to on until
/// the user turns it off.
class NotificationSettings {
  final bool nearbyRecommendations;
  final bool favoriteUpdates;
  final bool newDiscoveries;
  final bool general;

  const NotificationSettings({
    this.nearbyRecommendations = true,
    this.favoriteUpdates = true,
    this.newDiscoveries = true,
    this.general = true,
  });

  // Firestore field names — shared by the reader and the toggle writes.
  static const String nearbyRecommendationsKey = 'nearbyRecommendations';
  static const String favoriteUpdatesKey = 'favoriteUpdates';
  static const String newDiscoveriesKey = 'newDiscoveries';
  static const String generalKey = 'general';

  factory NotificationSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const NotificationSettings();
    return NotificationSettings(
      nearbyRecommendations: (data[nearbyRecommendationsKey] as bool?) ?? true,
      favoriteUpdates: (data[favoriteUpdatesKey] as bool?) ?? true,
      newDiscoveries: (data[newDiscoveriesKey] as bool?) ?? true,
      general: (data[generalKey] as bool?) ?? true,
    );
  }
}
