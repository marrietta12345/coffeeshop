import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/fitted_image.dart';
import '../theme/app_colors.dart';
import '../widgets/top_banner.dart';
import '../widgets/auth_text_field.dart';
import '../utils/page_transitions.dart';
import '../utils/user_role.dart';
import '../utils/auth_error_messages.dart';
import '../utils/supabase_image_service.dart';
import '../utils/form_validators.dart';
import '../utils/online_links.dart';
import '../models/operating_hours.dart';
import '../widgets/schedule_editor.dart';
import '../widgets/shop_location_section.dart';
import 'business_sign_in_page.dart';

/// Sign-up for Coffee Shop Owner accounts — sectioned form (Personal
/// Information / Coffee Shop Information) on a plain white page, matching
/// the reference design. Writes role: 'owner' so this account can never
/// sign in through the Coffee Explorer login.
///
/// Location (shared ShopLocationSection): the owner picks a Location Type
/// — Standalone / Street Location (Café Address) or Inside a Mall (Mall
/// Name, Floor Level, optional Unit, Landmark) — and must capture the
/// café's own GPS position before the account is created.
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
  final _location = ShopLocationController();
  // Online Presence (all optional).
  final _websiteController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  OperatingHours _hours = const OperatingHours(); // set by the owner (optional)
  bool _isLoading = false;
  // Errors show on submit first, then update live as the user fixes them.
  AutovalidateMode _autovalidate = AutovalidateMode.disabled;
  XFile? _logoFile;
  XFile? _bannerFile;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _shopNameController.dispose();
    _location.dispose();
    _websiteController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90, maxWidth: 800);
    if (picked == null || !mounted) return;
    final use = await confirmPhoto(context, image: FileImage(File(picked.path)), aspectRatio: ImageRatios.square, title: 'Use this logo?');
    if (use && mounted) setState(() => _logoFile = picked);
  }

  Future<void> _pickBanner() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1920);
    if (picked == null || !mounted) return;
    final use = await confirmPhoto(context, image: FileImage(File(picked.path)), aspectRatio: ImageRatios.banner, title: 'Use this cover photo?');
    if (use && mounted) setState(() => _bannerFile = picked);
  }

  Future<void> _handleSignUp() async {
    final fieldsOk = _formKey.currentState!.validate();
    final gpsOk = _location.validateGps();
    if (!fieldsOk || !gpsOk) {
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
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

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Account creation failed unexpectedly.');

      await user.updateDisplayName(_nameController.text.trim());

      // Everything about where the café is — saved on both the owner's
      // account and the public shop listing (a mall café reuses or adds
      // the shared mall record, now that the owner is signed in).
      final locationFields = await _location.toFirestore();

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
                      ShopLocationSection(controller: _location),
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
                        // The 16:9 cover box, with the whole photo inside it.
                        child: Container(
                          width: double.infinity,
                          height: (MediaQuery.sizeOf(context).width - 48) / ImageRatios.banner,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.inputFill,
                            borderRadius: BorderRadius.circular(14),
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
                              : FittedImage(image: FileImage(File(_bannerFile!.path)), width: double.infinity, height: double.infinity),
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
