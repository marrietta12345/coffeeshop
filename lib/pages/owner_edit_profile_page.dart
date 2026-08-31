import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../models/coffee_shop.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/top_banner.dart';

/// Edit the shop's basic profile info — name, description, phone, and
/// website. Writes straight to the shop's Firestore document.
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
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shop.name);
    _descriptionController = TextEditingController(text: widget.shop.description);
    _phoneController = TextEditingController(text: widget.shop.phoneNumber ?? '');
    _websiteController = TextEditingController(text: widget.shop.website ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('shops').doc(widget.shop.id).set({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'website': _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
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
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Phone Number',
                        controller: _phoneController,
                        hint: 'Optional',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 18),
                      AuthTextField(
                        label: 'Website',
                        controller: _websiteController,
                        hint: 'Optional',
                        keyboardType: TextInputType.url,
                      ),
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
}