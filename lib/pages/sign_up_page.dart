import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_colors.dart';
import '../widgets/top_banner.dart';
import '../widgets/auth_text_field.dart';
import '../utils/page_transitions.dart';
import '../utils/user_role.dart';
import '../utils/auth_error_messages.dart';
import 'sign_in_page.dart';

/// Sign-up for Coffee Explorer (customer) accounts. Writes a role document
/// to Firestore so SignInPage can verify — at login — that this account
/// was actually created as a customer, not a shop owner.
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Account creation failed unexpectedly.');

      await user.updateDisplayName(_nameController.text.trim());

      // Record this account as a Coffee Explorer so sign-in can enforce
      // that it's only ever used through the customer login. Wrapped in
      // a timeout so a Firestore misconfiguration (missing database,
      // blocked security rules) can never freeze the UI indefinitely —
      // the button always resolves one way or another within 12s.
      bool profileSaved = true;
      try {
        await FirebaseFirestore.instance.collection(usersCollection).doc(user.uid).set({
          'role': UserRole.customer.value,
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
      } on TimeoutException {
        debugPrint('Firestore write timed out for uid=${user.uid}');
        profileSaved = false;
      } on FirebaseException catch (e) {
        debugPrint('Firestore write failed: code=${e.code} message=${e.message}');
        profileSaved = false;
      }

      if (!mounted) return;

      if (profileSaved) {
        showTopBanner(context, 'Account created successfully!', isSuccess: true);
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
      Navigator.of(context).pushReplacement(slideUpRoute(const SignInPage()));
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
      backgroundColor: AppColors.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Sign Up',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 10),
                        const AuthRoleBadge(icon: Icons.coffee_rounded, label: 'Coffee Explorer'),
                        const SizedBox(height: 12),
                        const Text(
                          'Fill your information below',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        AuthTextField(
                          label: 'Full Name',
                          labelIcon: Icons.person_outline,
                          controller: _nameController,
                          hint: 'Enter your full name',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your full name';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        AuthPasswordField(
                          label: 'Password',
                          controller: _passwordController,
                          hint: 'Enter your password',
                          validator: (value) {
                            if (value == null || value.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        AuthTextField(
                          label: 'Email Address',
                          labelIcon: Icons.email_outlined,
                          controller: _emailController,
                          hint: 'Enter your email address',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your email';
                            if (!value.contains('@')) return 'Please enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        AuthSubmitButton(
                          label: 'Sign Up',
                          isLoading: _isLoading,
                          onPressed: _handleSignUp,
                        ),
                        const SizedBox(height: 16),
                        AuthSwitchRow(
                          question: 'Already have an account? ',
                          actionLabel: 'Sign In',
                          onTap: () => Navigator.pushReplacement(context, slideUpRoute(const SignInPage())),
                        ),
                      ],
                    ),
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