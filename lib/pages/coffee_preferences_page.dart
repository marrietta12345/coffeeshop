import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_preferences.dart';
import '../utils/user_profile_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/category_chip.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/top_banner.dart';

/// Lets the Coffee Explorer pick what they like — coffee types,
/// atmosphere and must-have amenities — saved to
/// `users/{uid}.coffeePreferences` for personalizing discovery later.
class CoffeePreferencesPage extends StatefulWidget {
  const CoffeePreferencesPage({super.key});

  @override
  State<CoffeePreferencesPage> createState() => _CoffeePreferencesPageState();
}

class _CoffeePreferencesPageState extends State<CoffeePreferencesPage> {
  bool _isLoading = true;
  bool _isSaving = false;

  final Set<String> _coffeeTypes = {};
  final Set<String> _atmospheres = {};
  bool _studyFriendly = false;
  bool _outdoorSeating = false;
  bool _wifi = false;
  bool _petFriendly = false;

  static const Map<String, IconData> _coffeeTypeIcons = {
    'Espresso': Icons.coffee_rounded,
    'Latte': Icons.local_cafe_rounded,
    'Cappuccino': Icons.local_cafe_outlined,
    'Americano': Icons.coffee_outlined,
    'Cold Brew': Icons.ac_unit_rounded,
    'Pour-over': Icons.water_drop_outlined,
    'Non-coffee': Icons.emoji_food_beverage_outlined,
  };

  static const Map<String, IconData> _atmosphereIcons = {
    'Cozy': Icons.weekend_outlined,
    'Quiet': Icons.volume_off_outlined,
    'Lively': Icons.groups_outlined,
    'Modern': Icons.apartment_rounded,
    'Rustic': Icons.forest_outlined,
    'Minimalist': Icons.crop_square_rounded,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var prefs = const CoffeePreferences();
    try {
      final profile = await UserProfileService.fetchProfile();
      prefs = CoffeePreferences.fromMap(profile['coffeePreferences'] as Map<String, dynamic>?);
    } catch (_) {
      // Start from defaults if it can't be loaded.
    }
    if (!mounted) return;
    setState(() {
      _coffeeTypes.addAll(prefs.coffeeTypes);
      _atmospheres.addAll(prefs.atmospheres);
      _studyFriendly = prefs.studyFriendly;
      _outdoorSeating = prefs.outdoorSeating;
      _wifi = prefs.wifi;
      _petFriendly = prefs.petFriendly;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final prefs = CoffeePreferences(
      coffeeTypes: _coffeeTypes,
      atmospheres: _atmospheres,
      studyFriendly: _studyFriendly,
      outdoorSeating: _outdoorSeating,
      wifi: _wifi,
      petFriendly: _petFriendly,
    );
    try {
      // Every key is written and arrays are replaced wholesale on merge,
      // so deselected chips are removed from the saved lists. Also clears
      // the price range an earlier version of this screen saved.
      await UserProfileService.update({
        'coffeePreferences': {...prefs.toMap(), 'priceRange': FieldValue.delete()},
      });
      if (!mounted) return;
      showTopBanner(context, 'Preferences saved!', isSuccess: true);
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      showTopBanner(context, "Couldn't save preferences. Please try again.", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleIn(Set<String> set, String value) {
    setState(() => set.contains(value) ? set.remove(value) : set.add(value));
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Coffee Preferences',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      const Text(
                        'Tell us what you like and we\'ll use it to suggest cafés for you.',
                        style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
                      ),
                      const SizedBox(height: 20),
                      const AuthSectionLabel('Coffee Type'),
                      const SizedBox(height: 10),
                      _chipWrap([
                        for (final type in CoffeePreferences.coffeeTypeOptions)
                          CategoryChip(
                            label: type,
                            icon: _coffeeTypeIcons[type] ?? Icons.coffee_outlined,
                            selected: _coffeeTypes.contains(type),
                            onTap: () => _toggleIn(_coffeeTypes, type),
                          ),
                      ]),
                      const SizedBox(height: 22),
                      const AuthSectionLabel('Café Atmosphere'),
                      const SizedBox(height: 10),
                      _chipWrap([
                        for (final mood in CoffeePreferences.atmosphereOptions)
                          CategoryChip(
                            label: mood,
                            icon: _atmosphereIcons[mood] ?? Icons.storefront_outlined,
                            selected: _atmospheres.contains(mood),
                            onTap: () => _toggleIn(_atmospheres, mood),
                          ),
                      ]),
                      const SizedBox(height: 22),
                      const AuthSectionLabel('Must-haves'),
                      const SizedBox(height: 10),
                      SettingsSwitchTile(
                        icon: Icons.menu_book_outlined,
                        title: 'Study-friendly',
                        value: _studyFriendly,
                        onChanged: (v) => setState(() => _studyFriendly = v),
                      ),
                      SettingsSwitchTile(
                        icon: Icons.deck_outlined,
                        title: 'Outdoor seating',
                        value: _outdoorSeating,
                        onChanged: (v) => setState(() => _outdoorSeating = v),
                      ),
                      SettingsSwitchTile(
                        icon: Icons.wifi_rounded,
                        title: 'Wi-Fi',
                        value: _wifi,
                        onChanged: (v) => setState(() => _wifi = v),
                      ),
                      SettingsSwitchTile(
                        icon: Icons.pets_outlined,
                        title: 'Pet-friendly',
                        value: _petFriendly,
                        onChanged: (v) => setState(() => _petFriendly = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AuthSubmitButton(label: 'Save Preferences', isLoading: _isSaving, onPressed: _save),
              ],
            ),
    );
  }

  Widget _chipWrap(List<Widget> chips) => Wrap(spacing: 8, runSpacing: 10, children: chips);
}
