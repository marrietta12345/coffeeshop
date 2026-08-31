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
import 'business_sign_in_page.dart';
import 'pick_shop_location_page.dart';

/// Sign-up for Coffee Shop Owner accounts — sectioned form (Personal
/// Information / Coffee Shop Information) on a plain white page, matching
/// the reference design. Writes role: 'owner' so this account can never
/// sign in through the Coffee Explorer login.
///
/// The shop address is validated (geocoded) BEFORE the account is
/// created — an address that can't be located is rejected outright,
/// rather than silently creating a shop with no real position on the map.
class BusinessSignUpPage extends StatefulWidget {
  const BusinessSignUpPage({super.key});

  @override
  State<BusinessSignUpPage> createState() => _BusinessSignUpPageState();
}

class _BusinessSignUpPageState extends State<BusinessSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  bool _isLocating = false;
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

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Validate the address BEFORE creating any account — an address that
    // can't be resolved to real coordinates is rejected outright, rather
    // than silently creating a shop that will never show up correctly on
    // the map. A pin placed via the map picker always counts as valid,
    // since that's already a confirmed real coordinate.
    double? latitude = _pickedLocation?.latitude;
    double? longitude = _pickedLocation?.longitude;

    if (latitude == null || longitude == null) {
      try {
        final locations = await locationFromAddress(_addressController.text.trim())
            .timeout(const Duration(seconds: 8));
        if (locations.isNotEmpty) {
          latitude = locations.first.latitude;
          longitude = locations.first.longitude;
        }
      } catch (e) {
        debugPrint('Geocoding failed for "${_addressController.text.trim()}": $e');
      }
    }

    if (latitude == null || longitude == null) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      showTopBanner(
        context,
        "We couldn't find that address. Please check it, or use \"Pick exact "
        "location on map\" to set your shop's position directly.",
        isSuccess: false,
        duration: const Duration(seconds: 4),
      );
      return;
    }

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
          'phoneNumber': _phoneController.text.trim(),
          'shopName': _shopNameController.text.trim(),
          'address': _addressController.text.trim(),
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
          'address': _addressController.text.trim(),
          'openTime': '8 AM',
          'closeTime': '8 PM',
          'latitude': latitude,
          'longitude': longitude,
          'rating': 0,
          'isOpenNow': true,
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
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Full Name',
                        controller: _nameController,
                        hint: 'Enter your full name',
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your full name';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Email',
                        controller: _emailController,
                        hint: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your email';
                          if (!value.contains('@')) return 'Please enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        hint: 'Enter your phone number',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your phone number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthPasswordField(
                        label: 'Password',
                        controller: _passwordController,
                        hint: 'Create a password',
                        validator: (value) {
                          if (value == null || value.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),
                      const AuthSectionLabel('Coffee Shop Information'),
                      const SizedBox(height: 16),
                      AuthTextField(
                        label: 'Coffee Shop Name',
                        controller: _shopNameController,
                        hint: 'Enter coffee shop name',
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your coffee shop name';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Shop Address',
                        controller: _addressController,
                        hint: 'e.g. J.C. Aquino Ave, Butuan City',
                        keyboardType: TextInputType.streetAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your shop address';
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'We\'ll verify this is a real, locatable address before creating your account.',
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _isLocating ? null : _handlePickLocation,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: _pickedLocation != null
                                ? AppColors.primaryBrown.withOpacity(0.08)
                                : AppColors.inputFill,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _pickedLocation != null
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
                                  _pickedLocation != null ? Icons.check_circle_rounded : Icons.map_outlined,
                                  size: 20,
                                  color: AppColors.primaryBrown,
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _pickedLocation != null
                                      ? 'Pin placed — tap to adjust on map'
                                      : 'Pick exact location on map',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryBrown,
                                  ),
                                ),
                              ),
                              if (!_isLocating) const Icon(Icons.chevron_right_rounded, color: AppColors.primaryBrown),
                            ],
                          ),
                        ),
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