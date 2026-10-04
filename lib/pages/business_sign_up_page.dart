import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../widgets/top_banner.dart';
import '../widgets/auth_text_field.dart';
import '../utils/page_transitions.dart';
import '../utils/user_role.dart';
import '../utils/auth_error_messages.dart';
import '../utils/supabase_image_service.dart';
import '../utils/form_validators.dart';
import '../utils/location_service.dart';
import '../utils/online_links.dart';
import '../models/operating_hours.dart';
import '../widgets/schedule_editor.dart';
import 'business_sign_in_page.dart';
import 'pick_shop_location_page.dart';

/// Sign-up for Coffee Shop Owner accounts — sectioned form (Personal
/// Information / Coffee Shop Information) on a plain white page, matching
/// the reference design. Writes role: 'owner' so this account can never
/// sign in through the Coffee Explorer login.
///
/// Location: the owner picks a Location Type — Standalone / Street
/// Location (Café Address) or Inside a Mall (Mall Name, Floor Level,
/// optional Landmark) — and must capture the café's GPS position ("Use
/// Current Location" or the map picker) before the account is created.
class BusinessSignUpPage extends StatefulWidget {
  const BusinessSignUpPage({super.key});

  @override
  State<BusinessSignUpPage> createState() => _BusinessSignUpPageState();
}

class _BusinessSignUpPageState extends State<BusinessSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController(text: FormValidators.phMobilePrefix);
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mallNameController = TextEditingController();
  final _mallFloorController = TextEditingController();
  final _mallLandmarkController = TextEditingController();
  // Online Presence (all optional).
  final _websiteController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  bool _isMall = false; // Location Type: false = Standalone / Street
  OperatingHours _hours = const OperatingHours(); // set by the owner (optional)
  bool _gpsMissing = false; // show the GPS error after a failed submit
  bool _isLoading = false;
  bool _isLocating = false;
  // Errors show on submit first, then update live as the user fixes them.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  LatLng? _pickedLocation;
  XFile? _logoFile;
  XFile? _bannerFile;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _addressController.dispose();
    _mallNameController.dispose();
    _mallFloorController.dispose();
    _mallLandmarkController.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _logoFile = picked);
  }

  Future<void> _pickBanner() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _bannerFile = picked);
  }

  Future<void> _handlePickLocation() async {
    setState(() => _isLocating = true);

    // Default fallback center (Butuan City). If the owner already
    // typed an address, try to geocode it so the map opens near there —
    // but this is optional, not required, to open the picker.
    LatLng startCenter = _pickedLocation ?? const LatLng(8.9475, 125.5406);
    if (_pickedLocation == null && _addressController.text.trim().isNotEmpty) {
      try {
        final locations = await locationFromAddress(_addressController.text.trim())
            .timeout(const Duration(seconds: 8));
        if (locations.isNotEmpty) {
          startCenter = LatLng(locations.first.latitude, locations.first.longitude);
        }
      } catch (e) {
        debugPrint('Geocoding failed for "${_addressController.text.trim()}": $e');
      }
    }

    if (!mounted) return;
    setState(() => _isLocating = false);

    final result = await Navigator.push<LatLng>(
      context,
      slideUpRoute(PickShopLocationPage(initialCenter: startCenter)),
    );

    if (result == null || !mounted) return;

    setState(() {
      _pickedLocation = result;
      _gpsMissing = false;
      _isLocating = true;
    });

    // Reverse-geocode the confirmed pin into a readable address so the
    // owner doesn't have to type one manually at all if they don't want to.
    try {
      final placemarks = await placemarkFromCoordinates(result.latitude, result.longitude)
          .timeout(const Duration(seconds: 8));
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final parts = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
        ].where((part) => part != null && part.trim().isNotEmpty).toList();
        if (parts.isNotEmpty && mounted) {
          _addressController.text = parts.join(', ');
        }
      }
    } catch (e) {
      debugPrint('Reverse geocoding failed for $result: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  /// Captures the café's GPS position from the phone, then fills in a
  /// readable address from it (for mall cafés, or when the address field
  /// is still empty).
  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    final result = await getCurrentLocation();
    if (!mounted) return;
    if (!result.isSuccess) {
      setState(() => _isLocating = false);
      showTopBanner(context, result.errorMessage!, isSuccess: false, duration: const Duration(seconds: 3));
      return;
    }
    final here = result.position!;
    setState(() {
      _pickedLocation = here;
      _gpsMissing = false;
    });
    if (_isMall || _addressController.text.trim().isEmpty) {
      try {
        final placemarks = await placemarkFromCoordinates(here.latitude, here.longitude)
            .timeout(const Duration(seconds: 8));
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          final parts = [place.street, place.subLocality, place.locality, place.administrativeArea]
              .where((part) => part != null && part.trim().isNotEmpty)
              .toList();
          if (parts.isNotEmpty) _addressController.text = parts.join(', ');
        }
      } catch (e) {
        debugPrint('Reverse geocoding failed for $here: $e');
      }
    }
    if (mounted) setState(() => _isLocating = false);
  }

  Future<void> _handleSignUp() async {
    final fieldsOk = _formKey.currentState!.validate();
    final gpsOk = _pickedLocation != null;
    if (!fieldsOk || !gpsOk) {
      setState(() {
        _autovalidate = AutovalidateMode.onUserInteraction;
        _gpsMissing = !gpsOk;
      });
      showTopBanner(
        context,
        fieldsOk
            ? "Please capture your café's GPS location before continuing."
            : 'Please complete the required fields correctly.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isLoading = true);

    final latitude = _pickedLocation!.latitude;
    final longitude = _pickedLocation!.longitude;
    final landmark = _mallLandmarkController.text.trim();
    // Everything about where the café is — saved on both the owner's
    // account and the public shop listing.
    final locationFields = <String, dynamic>{
      'locationType': _isMall ? 'mall' : 'standalone',
      'mallName': _isMall ? _mallNameController.text.trim() : null,
      'mallFloor': _isMall ? _mallFloorController.text.trim() : null,
      'mallLandmark': _isMall && landmark.isNotEmpty ? landmark : null,
      // Mall cafés: the address looked up from their GPS position (may be
      // empty — the mall name is what customers see).
      'address': _addressController.text.trim(),
      'latitude': latitude,
      'longitude': longitude,
    };

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Account creation failed unexpectedly.');

      await user.updateDisplayName(_nameController.text.trim());

      // Record this account as a Coffee Shop Owner so sign-in can enforce
      // that it's only ever used through the owner login. Wrapped in a
      // timeout so a Firestore misconfiguration can never freeze the UI.
      bool profileSaved = true;
      String? shopId;
      try {
        await FirebaseFirestore.instance.collection(usersCollection).doc(user.uid).set({
          'role': UserRole.owner.value,
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phoneNumber': FormValidators.normalizePhMobile(_phoneController.text),
          'shopName': _shopNameController.text.trim(),
          ...locationFields,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));

        // Separate PUBLIC document so customers can read it on the map —
        // the `users` doc above stays private (owner-only), but shop
        // listings need to be readable by everyone. Written with the
        // shop's own generated ID (not the owner's uid) so one owner
        // could eventually manage multiple shops.
        final shopDoc = await FirebaseFirestore.instance.collection('shops').add({
          'ownerId': user.uid,
          'name': _shopNameController.text.trim(),
          'description': '',
          // Also on the public listing, for Edit Profile and customers' Call button.
          'phoneNumber': FormValidators.normalizePhMobile(_phoneController.text),
          ...locationFields,
          'website': OnlineLinks.toStored(_websiteController.text),
          'facebookUrl': OnlineLinks.toStored(_facebookController.text),
          'instagramUrl': OnlineLinks.toStored(_instagramController.text),
          'tiktokUrl': OnlineLinks.toStored(_tiktokController.text),
          'operatingHours': _hours.toFirestoreMap(),
          'temporarilyClosed': false,
          'rating': 0,
          'photoUrls': <String>[],
          'viewCount': 0,
          'favoritesCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
        shopId = shopDoc.id;

        // Upload the logo/banner (if picked) to Supabase Storage now that
        // we have a real shopId, then save their URLs onto the shop doc.
        // Best-effort — a failed image upload shouldn't block account
        // creation, since the owner can always add these later from
        // their Profile page.
        final Map<String, dynamic> imageUpdates = {};
        if (_logoFile != null) {
          try {
            final url = await SupabaseImageService.uploadImage(
              file: File(_logoFile!.path),
              folder: 'logos',
              shopId: shopId,
              fileName: 'logo.jpg',
            );
            imageUpdates['logoUrl'] = url;
          } catch (e) {
            debugPrint('Logo upload failed: $e');
          }
        }
        if (_bannerFile != null) {
          try {
            final url = await SupabaseImageService.uploadImage(
              file: File(_bannerFile!.path),
              folder: 'banners',
              shopId: shopId,
              fileName: 'banner.jpg',
            );
            imageUpdates['bannerUrl'] = url;
          } catch (e) {
            debugPrint('Banner upload failed: $e');
          }
        }
        if (imageUpdates.isNotEmpty) {
          await FirebaseFirestore.instance.collection('shops').doc(shopId).set(
            imageUpdates,
            SetOptions(merge: true),
          );
        }
      } on TimeoutException {
        debugPrint('Firestore write timed out for uid=${user.uid}');
        profileSaved = false;
      } on FirebaseException catch (e) {
        debugPrint('Firestore write failed: code=${e.code} message=${e.message}');
        profileSaved = false;
      }

      if (!mounted) return;

      if (profileSaved) {
        showTopBanner(context, 'Business account created successfully!', isSuccess: true);
      } else {
        showTopBanner(
          context,
          'Account created, but saving your profile failed. Please check your '
          'internet connection or contact support if this keeps happening.',
          isSuccess: false,
          duration: const Duration(seconds: 4),
        );
      }

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(slideUpRoute(const BusinessSignInPage()));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showTopBanner(context, signUpErrorMessage(e.code), isSuccess: false);
    } catch (e) {
      if (!mounted) return;
      showTopBanner(context, 'Something went wrong. Please try again.', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// A field label with the red required "*" — same look as AuthTextField's.
  Widget _requiredLabel(String text) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const Text(' *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD64545))),
      ],
    );
  }

  /// GPS status ("📍 Captured Location" + coordinates, or not yet), with
  /// "Use Current Location" and "Pick on Map" buttons and, after a failed
  /// submit, a red error if no location was captured.
  Widget _buildGpsCard(BuildContext context) {
    final location = _pickedLocation;
    final errorColor = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: location != null ? AppColors.primaryBrown.withOpacity(0.08) : AppColors.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _gpsMissing
                  ? errorColor
                  : location != null
                      ? AppColors.primaryBrown.withOpacity(0.4)
                      : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (_isLocating)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBrown),
                )
              else
                Icon(
                  location != null ? Icons.check_circle_rounded : Icons.location_searching_rounded,
                  size: 20,
                  color: AppColors.primaryBrown,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLocating
                          ? 'Getting location…'
                          : location != null
                              ? '📍 Captured Location'
                              : 'No location captured yet',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryBrown),
                    ),
                    if (location != null && !_isLocating)
                      Text(
                        '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBrown,
                  elevation: 0,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLocating ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location_rounded, size: 18, color: Colors.white),
                label: const Text(
                  'Use Current Location',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  side: BorderSide(color: AppColors.primaryBrown.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLocating ? null : _handlePickLocation,
                icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.primaryBrown),
                label: const Text(
                  'Pick on Map',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBrown),
                ),
              ),
            ),
          ],
        ),
        if (_gpsMissing) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              "Please capture your café's GPS location.",
              style: TextStyle(fontSize: 12, color: errorColor),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _autovalidate,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Your\nBusiness Account',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const AuthRoleBadge(icon: Icons.storefront_rounded, label: 'Coffee Shop Owner'),
                      const SizedBox(height: 12),
                      const Text(
                        'Fill in the details below to register your coffee shop.',
                        style: TextStyle(color: AppColors.textGrey, fontSize: 13.5),
                      ),
                      const SizedBox(height: 28),
                      const AuthSectionLabel('Personal Information'),
                      const SizedBox(height: 4),
                      const Text.rich(
                        TextSpan(
                          style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                          children: [
                            TextSpan(text: 'Fields marked '),
                            TextSpan(text: '*', style: TextStyle(color: Color(0xFFD64545), fontWeight: FontWeight.w700)),
                            TextSpan(text: ' are required.'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Full Name',
                        controller: _nameController,
                        hint: 'Enter your full name',
                        isRequired: true,
                        validator: FormValidators.required,
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Email',
                        controller: _emailController,
                        hint: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        isRequired: true,
                        validator: FormValidators.email,
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        hint: '+639XXXXXXXXX',
                        keyboardType: TextInputType.phone,
                        isRequired: true,
                        inputFormatters: const [PhMobileInputFormatter()],
                        validator: FormValidators.phMobile,
                      ),
                      const SizedBox(height: 18),
                      AuthPasswordField(
                        label: 'Password',
                        controller: _passwordController,
                        hint: 'Create a password (min. 6 characters)',
                        isRequired: true,
                        validator: FormValidators.password,
                      ),
                      const SizedBox(height: 28),
                      const AuthSectionLabel('Coffee Shop Information'),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Coffee Shop Name',
                        controller: _shopNameController,
                        hint: 'Enter coffee shop name',
                        isRequired: true,
                        validator: FormValidators.required,
                      ),
                      const SizedBox(height: 18),
                      _requiredLabel('Location Type'),
                      const SizedBox(height: 8),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _LocationTypeOption(
                                label: 'Standalone / Street Location',
                                icon: Icons.storefront_outlined,
                                selected: !_isMall,
                                onTap: () => setState(() => _isMall = false),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _LocationTypeOption(
                                label: 'Inside a Mall',
                                icon: Icons.local_mall_outlined,
                                selected: _isMall,
                                onTap: () => setState(() => _isMall = true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      if (_isMall) ...[
                        AuthTextField(
                          label: 'Mall Name',
                          controller: _mallNameController,
                          hint: 'e.g. Gaisano Mall Butuan',
                          isRequired: true,
                          validator: FormValidators.required,
                        ),
                        const SizedBox(height: 18),
                        AuthTextField(
                          label: 'Floor Level',
                          controller: _mallFloorController,
                          hint: 'e.g. 2nd Floor',
                          isRequired: true,
                          validator: FormValidators.required,
                        ),
                        const SizedBox(height: 18),
                        AuthTextField(
                          label: 'Specific Location / Landmark',
                          controller: _mallLandmarkController,
                          hint: 'Optional — e.g. Near the Food Court',
                        ),
                      ] else
                        AuthTextField(
                          label: 'Café Address',
                          controller: _addressController,
                          hint: 'e.g. J.C. Aquino Ave, Butuan City',
                          keyboardType: TextInputType.streetAddress,
                          isRequired: true,
                          validator: FormValidators.required,
                        ),
                      const SizedBox(height: 18),
                      _requiredLabel('Café GPS Location'),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap "Use Current Location" while you\'re at your café, or pick it on the map.',
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 10),
                      _buildGpsCard(context),
                      const SizedBox(height: 28),
                      const AuthSectionLabel('Operating Hours'),
                      const SizedBox(height: 4),
                      const Text(
                        'Optional — set the days and hours you\'re open. You can change them anytime.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 16),
                      ScheduleEditor(value: _hours, onChanged: (h) => setState(() => _hours = h)),
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
                      const SizedBox(height: 24),
                      const Text('Shop Logo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      const Text('Optional — you can add this later too.', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickLogo,
                        borderRadius: BorderRadius.circular(50),
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.inputFill,
                            image: _logoFile != null
                                ? DecorationImage(image: FileImage(File(_logoFile!.path)), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _logoFile == null
                              ? const Icon(Icons.add_a_photo_outlined, color: AppColors.primaryBrown, size: 26)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text('Shop Banner', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark)),
                      const SizedBox(height: 4),
                      const Text('Optional — you can add this later too.', style: TextStyle(fontSize: 11, color: AppColors.textGrey)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _pickBanner,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(14),
                            image: _bannerFile != null
                                ? DecorationImage(image: FileImage(File(_bannerFile!.path)), fit: BoxFit.cover)
                                : null,
                          ),
                          child: _bannerFile == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.image_outlined, color: AppColors.primaryBrown, size: 26),
                                    SizedBox(height: 6),
                                    Text('Add a cover photo', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 32),
                      AuthSubmitButton(
                        label: 'Continue',
                        isLoading: _isLoading,
                        onPressed: _handleSignUp,
                      ),
                      const SizedBox(height: 16),
                      AuthSwitchRow(
                        question: 'Already have an account? ',
                        actionLabel: 'Sign In',
                        onTap: () => Navigator.pushReplacement(context, slideUpRoute(const BusinessSignInPage())),
                      ),
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
}

/// One of the two Location Type choices — equal-width tiles in the same
/// brown / light-grey look as the rest of the form.
class _LocationTypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _LocationTypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : AppColors.textDark;
    return Material(
      color: selected ? AppColors.primaryBrown : AppColors.inputFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : AppColors.primaryBrown),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color, height: 1.25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
