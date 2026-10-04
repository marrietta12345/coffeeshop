import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_colors.dart';
import '../utils/user_profile_service.dart';
import '../utils/supabase_image_service.dart';
import '../utils/auth_error_messages.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/top_banner.dart';

/// View + edit the Coffee Explorer's profile: photo, name, username and
/// email. Name and photo are kept on both the Firebase Auth user (so the
/// Profile tab updates instantly) and `users/{uid}`. Email changes go
/// through Firebase's verify-before-update flow, so the address only
/// switches once the user confirms it from their new inbox.
class PersonalInfoPage extends StatefulWidget {
  const PersonalInfoPage({super.key});

  @override
  State<PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends State<PersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;
  File? _pickedPhoto;

  String _name = '';
  String _username = '';
  String _email = '';
  String? _photoUrl;

  static final _usernamePattern = RegExp(r'^[a-z0-9._]{3,20}$');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic> profile = const {};
    try {
      profile = await UserProfileService.fetchProfile();
    } catch (_) {
      // Fall back to what Firebase Auth knows.
    }
    if (!mounted) return;
    setState(() {
      _name = user?.displayName ?? (profile['fullName'] as String?) ?? '';
      _username = (profile['username'] as String?) ?? '';
      _email = user?.email ?? '';
      _photoUrl = user?.photoURL ?? profile['photoUrl'] as String?;
      _isLoading = false;
    });
  }

  void _startEditing() {
    _nameController.text = _name;
    _usernameController.text = _username;
    _emailController.text = _email;
    setState(() {
      _pickedPhoto = null;
      _isEditing = true;
    });
  }

  void _cancelEditing() {
    FocusScope.of(context).unfocus();
    setState(() {
      _pickedPhoto = null;
      _isEditing = false;
    });
  }

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (picked == null) return;
    setState(() => _pickedPhoto = File(picked.path));
  }

  /// Asks for the current password — Firebase requires a recent sign-in
  /// before changing the account email.
  Future<String?> _askForPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm your password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'For your security, enter your current password to change your email.',
              style: TextStyle(fontSize: 13, color: AppColors.textGrey, height: 1.4),
            ),
            const SizedBox(height: 14),
            AuthPasswordField(label: 'Password', controller: controller, hint: 'Your current password'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBrown),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FocusScope.of(context).unfocus();

    final newName = _nameController.text.trim();
    final newUsername = _usernameController.text.trim().toLowerCase();
    final newEmail = _emailController.text.trim();
    final emailChanged = newEmail.toLowerCase() != _email.toLowerCase();

    String? password;
    if (emailChanged) {
      password = await _askForPassword();
      if (password == null || password.isEmpty) return;
    }

    setState(() => _isSaving = true);
    try {
      // Verify the password first so a wrong one saves nothing at all.
      if (emailChanged) {
        await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: _email, password: password!),
        );
      }

      String? newPhotoUrl;
      if (_pickedPhoto != null) {
        // Timestamped name so the new photo isn't served from image cache.
        newPhotoUrl = await SupabaseImageService.uploadImage(
          file: _pickedPhoto!,
          folder: 'avatars',
          shopId: user.uid,
          fileName: 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        final oldPhotoUrl = _photoUrl;
        await user.updatePhotoURL(newPhotoUrl);
        if (oldPhotoUrl != null) {
          SupabaseImageService.deleteImageByUrl(oldPhotoUrl).catchError((_) {});
        }
      }

      if (newName != _name) await user.updateDisplayName(newName);

      await UserProfileService.update({
        'fullName': newName,
        'username': newUsername,
        if (newPhotoUrl != null) 'photoUrl': newPhotoUrl,
      });

      if (emailChanged) await user.verifyBeforeUpdateEmail(newEmail);

      if (!mounted) return;
      setState(() {
        _name = newName;
        _username = newUsername;
        if (newPhotoUrl != null) _photoUrl = newPhotoUrl;
        _pickedPhoto = null;
        _isEditing = false;
      });
      showTopBanner(
        context,
        emailChanged
            ? 'Saved! Check $newEmail to confirm your new email address.'
            : 'Profile updated!',
        isSuccess: true,
        duration: Duration(seconds: emailChanged ? 4 : 2),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'Incorrect password. Your email was not changed.',
        'email-already-in-use' => 'An account already exists for that email.',
        'invalid-email' => 'That email address looks invalid.',
        _ => signInErrorMessage(e.code),
      };
      showTopBanner(context, message, isSuccess: false, duration: const Duration(seconds: 3));
    } catch (_) {
      if (!mounted) return;
      showTopBanner(context, "Couldn't save changes. Please try again.", isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Personal Information',
      action: _isLoading
          ? null
          : SettingsHeaderButton(
              label: _isEditing ? 'Cancel' : 'Edit',
              onPressed: _isSaving ? null : (_isEditing ? _cancelEditing : _startEditing),
            ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBrown))
          : _isEditing
              ? _buildEditForm()
              : _buildDetails(),
    );
  }

  Widget _buildAvatar({required bool editable}) {
    ImageProvider? image;
    if (_pickedPhoto != null) {
      image = FileImage(_pickedPhoto!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      image = NetworkImage(_photoUrl!);
    }

    final avatar = CircleAvatar(
      radius: 44,
      backgroundColor: AppColors.primaryBrown.withOpacity(0.15),
      backgroundImage: image,
      child: image == null ? const Icon(Icons.person_rounded, color: AppColors.primaryBrown, size: 44) : null,
    );

    if (!editable) return Center(child: avatar);

    return Center(
      child: GestureDetector(
        onTap: _isSaving ? null : _pickPhoto,
        child: Stack(
          children: [
            avatar,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryBrown,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails() {
    return ListView(
      children: [
        const SizedBox(height: 8),
        _buildAvatar(editable: false),
        const SizedBox(height: 24),
        _InfoRow(icon: Icons.person_outline_rounded, label: 'Name', value: _name),
        _InfoRow(icon: Icons.alternate_email_rounded, label: 'Username', value: _username.isEmpty ? '' : '@$_username'),
        _InfoRow(icon: Icons.email_outlined, label: 'Email', value: _email),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          const SizedBox(height: 8),
          _buildAvatar(editable: true),
          const SizedBox(height: 8),
          const Center(
            child: Text('Tap photo to change', style: TextStyle(fontSize: 12, color: AppColors.textGrey)),
          ),
          const SizedBox(height: 20),
          AuthTextField(
            label: 'Name',
            labelIcon: Icons.person_outline_rounded,
            controller: _nameController,
            hint: 'Your full name',
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Username',
            labelIcon: Icons.alternate_email_rounded,
            controller: _usernameController,
            hint: 'e.g. coffee.lover',
            validator: (v) {
              final value = (v ?? '').trim().toLowerCase();
              if (value.isEmpty) return null; // optional
              if (!_usernamePattern.hasMatch(value)) {
                return '3–20 characters: letters, numbers, dots or underscores';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Email',
            labelIcon: Icons.email_outlined,
            controller: _emailController,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Please enter your email';
              if (!value.contains('@') || !value.contains('.')) return 'That email address looks invalid.';
              return null;
            },
          ),
          const SizedBox(height: 28),
          AuthSubmitButton(label: 'Save Changes', isLoading: _isSaving, onPressed: _save),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.inputFill, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryBrown, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: value.isEmpty ? AppColors.textGrey : AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
