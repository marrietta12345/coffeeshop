import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_preferences.dart';
import '../models/coffee_shop.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/category_chip.dart';
import '../widgets/top_banner.dart';
import '../widgets/shop_location_section.dart';
import '../widgets/business_permit_section.dart';
import '../utils/form_validators.dart';
import '../utils/user_profile_service.dart';
import '../utils/online_links.dart';

/// Edit the shop's basic profile info — name, description, phone,
/// Online Presence (website + social links), its Location (type, mall details,
/// address, GPS — same fields and rules as sign-up), and its Café Features
/// (coffee types, atmosphere, must-haves) that customers' Coffee
/// Preferences are matched against for "Recommended for You". Writes
/// straight to the shop's Firestore document. Also the optional Business
/// Permit (image or PDF), kept private on the owner's own profile.
class OwnerEditProfilePage extends StatefulWidget {
  final CoffeeShop shop;

  const OwnerEditProfilePage({super.key, required this.shop});

  @override
  State<OwnerEditProfilePage> createState() => _OwnerEditProfilePageState();
}

class _OwnerEditProfilePageState extends State<OwnerEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _phoneController;
  late final TextEditingController _websiteController;
  late final TextEditingController _facebookController;
  late final TextEditingController _instagramController;
  late final TextEditingController _tiktokController;
  late final ShopLocationController _location = ShopLocationController(shop: widget.shop);
  late final BusinessPermitController _permit = BusinessPermitController(shopId: widget.shop.id);
  late final Set<String> _coffeeTypes = {...widget.shop.coffeeTypes};
  late final Set<String> _atmospheres = {...widget.shop.atmospheres};
  late final Set<String> _amenities = {...widget.shop.amenities};
  bool _isSaving = false;

  void _toggleIn(Set<String> set, String value) {
    setState(() => set.contains(value) ? set.remove(value) : set.add(value));
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shop.name);
    _descriptionController = TextEditingController(text: widget.shop.description);
    _phoneController = TextEditingController(text: _formatPhone(widget.shop.phoneNumber));
    _websiteController = TextEditingController(text: widget.shop.website ?? '');
    _facebookController = TextEditingController(text: widget.shop.facebookUrl ?? '');
    _instagramController = TextEditingController(text: widget.shop.instagramUrl ?? '');
    _tiktokController = TextEditingController(text: widget.shop.tiktokUrl ?? '');
    if ((widget.shop.phoneNumber ?? '').trim().isEmpty) _loadSignUpPhone();
    _permit.load();
  }

  /// Shows a saved number in +639XXXXXXXXX form (or just the +639 prefix
  /// when there isn't one yet).
  static String _formatPhone(String? phone) {
    final normalized = FormValidators.normalizePhMobile(phone ?? '');
    return normalized.isEmpty ? FormValidators.phMobilePrefix : normalized;
  }

  /// Cafés created before the phone number was saved on the shop itself
  /// only have it on the owner's account (from sign-up) — show that one.
  Future<void> _loadSignUpPhone() async {
    try {
      final profile = await UserProfileService.fetchProfile();
      final phone = (profile['phoneNumber'] as String?)?.trim() ?? '';
      // Don't overwrite anything the owner has started typing.
      if (!mounted || phone.isEmpty || _phoneController.text != FormValidators.phMobilePrefix) return;
      final formatted = _formatPhone(phone);
      setState(() => _phoneController.text = formatted);
      // Copy it onto the café's listing so it shows here (and on the
      // customers' Call button) from now on.
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shop.id)
          .set({'phoneNumber': formatted}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Could not load sign-up phone number: $e');
    }
  }

  /// Optional, but if entered it must be a valid Philippine mobile number.
  static String? _validatePhone(String? value) {
    final normalized = FormValidators.normalizePhMobile(value ?? '');
    if (normalized.isEmpty || normalized == FormValidators.phMobilePrefix) return null;
    return FormValidators.phMobile(value);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _location.dispose();
    _permit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fieldsOk = _formKey.currentState!.validate();
    final gpsOk = _location.validateGps();
    // Field errors show under each field; a missing GPS spot also gets a banner.
    if (!fieldsOk) return;
    if (!gpsOk) {
      showTopBanner(context, "Please capture your café's GPS location.", isSuccess: false);
      return;
    }
    setState(() => _isSaving = true);

    // The permit is optional — this only uploads or removes it when the
    // owner changed it.
    try {
      await _permit.commit();
    } catch (e) {
      debugPrint('Could not save business permit: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      showTopBanner(context, "Couldn't upload your business permit. Please try again.", isSuccess: false);
      return;
    }

    try {
      // Location type, mall details, address and the café's own GPS spot.
      final locationFields = await _location.toFirestore();
      await FirebaseFirestore.instance.collection('shops').doc(widget.shop.id).set({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phoneNumber': _validatePhone(_phoneController.text) == null &&
                FormValidators.normalizePhMobile(_phoneController.text) != FormValidators.phMobilePrefix
            ? FormValidators.normalizePhMobile(_phoneController.text)
            : null,
        'website': OnlineLinks.toStored(_websiteController.text),
        'facebookUrl': OnlineLinks.toStored(_facebookController.text),
        'instagramUrl': OnlineLinks.toStored(_instagramController.text),
        'tiktokUrl': OnlineLinks.toStored(_tiktokController.text),
        ...locationFields,
        'coffeeTypes': _coffeeTypes.toList(),
        'atmospheres': _atmospheres.toList(),
        'amenities': _amenities.toList(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      showTopBanner(context, 'Profile updated!', isSuccess: true);
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showTopBanner(context, "Couldn't save changes. Please try again.", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.textDark), onPressed: () => Navigator.pop(context)),
                  const SizedBox(width: 4),
                  const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AuthTextField(
                        label: 'Shop Name',
                        controller: _nameController,
                        hint: 'Enter your shop name',
                        validator: (v) => (v == null || v.isEmpty) ? 'Please enter your shop name' : null,
                      ),
                      const SizedBox(height: 18),
                      const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Tell customers about your shop...',
                          filled: true,
                          fillColor: AppColors.inputFill,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        hint: '+639XXXXXXXXX',
                        keyboardType: TextInputType.phone,
                        inputFormatters: const [PhMobileInputFormatter()],
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 28),
                      const AuthSectionLabel('Online Presence'),
                      const SizedBox(height: 4),
                      const Text(
                        'All optional — add the links your café already has.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Website URL',
                        labelIcon: OnlinePlatform.website.icon,
                        controller: _websiteController,
                        hint: OnlinePlatform.website.example,
                        keyboardType: TextInputType.url,
                        validator: (v) => OnlineLinks.validate(OnlinePlatform.website, v),
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Facebook URL',
                        labelIcon: OnlinePlatform.facebook.icon,
                        controller: _facebookController,
                        hint: OnlinePlatform.facebook.example,
                        keyboardType: TextInputType.url,
                        validator: (v) => OnlineLinks.validate(OnlinePlatform.facebook, v),
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Instagram URL',
                        labelIcon: OnlinePlatform.instagram.icon,
                        controller: _instagramController,
                        hint: OnlinePlatform.instagram.example,
                        keyboardType: TextInputType.url,
                        validator: (v) => OnlineLinks.validate(OnlinePlatform.instagram, v),
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'TikTok URL',
                        labelIcon: OnlinePlatform.tiktok.icon,
                        controller: _tiktokController,
                        hint: OnlinePlatform.tiktok.example,
                        keyboardType: TextInputType.url,
                        validator: (v) => OnlineLinks.validate(OnlinePlatform.tiktok, v),
                      ),
                      const SizedBox(height: 28),
                      const AuthSectionLabel('Location'),
                      const SizedBox(height: 16),
                      ShopLocationSection(controller: _location),
                      const SizedBox(height: 28),
                      const AuthSectionLabel('Café Features'),
                      const SizedBox(height: 4),
                      const Text(
                        'Helps customers whose preferences match find your café.',
                        style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 16),
                      const Text('Coffee served', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      _chips([
                        for (final type in CoffeePreferences.coffeeTypeOptions)
                          CategoryChip(
                            label: type,
                            icon: Icons.local_cafe_outlined,
                            selected: _coffeeTypes.contains(type),
                            onTap: () => _toggleIn(_coffeeTypes, type),
                          ),
                      ]),
                      const SizedBox(height: 16),
                      const Text('Atmosphere', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      _chips([
                        for (final mood in CoffeePreferences.atmosphereOptions)
                          CategoryChip(
                            label: mood,
                            icon: Icons.storefront_outlined,
                            selected: _atmospheres.contains(mood),
                            onTap: () => _toggleIn(_atmospheres, mood),
                          ),
                      ]),
                      const SizedBox(height: 16),
                      const Text('Must-haves offered', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 8),
                      _chips([
                        for (final entry in CoffeePreferences.amenityLabels.entries)
                          CategoryChip(
                            label: entry.value,
                            icon: Icons.check_circle_outline_rounded,
                            selected: _amenities.contains(entry.key),
                            onTap: () => _toggleIn(_amenities, entry.key),
                          ),
                      ]),
                      const SizedBox(height: 28),
                      BusinessPermitSection(controller: _permit),
                      const SizedBox(height: 28),
                      AuthSubmitButton(label: 'Save Changes', isLoading: _isSaving, onPressed: _save),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chips(List<Widget> chips) => Wrap(spacing: 8, runSpacing: 10, children: chips);
}
