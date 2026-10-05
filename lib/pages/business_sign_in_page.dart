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
import 'business_sign_up_page.dart';
import 'owner_main_nav_page.dart';

/// Sign-in for Coffee Shop Owner accounts. Mirrors SignInPage exactly,
/// but checks for role == owner — a Coffee Explorer account attempting
/// to sign in here is rejected and signed back out immediately.
class BusinessSignInPage extends StatefulWidget {
  const BusinessSignInPage({super.key});

  @override
  State<BusinessSignInPage> createState() => _BusinessSignInPageState();
}

class _BusinessSignInPageState extends State<BusinessSignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final user = credential.user;
      if (user == null) throw Exception('Sign in failed unexpectedly.');

      DocumentSnapshot<Map<String, dynamic>> doc;
      try {
        doc = await FirebaseFirestore.instance
            .collection(usersCollection)
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 8));
      } on TimeoutException {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        showTopBanner(
          context,
          "Couldn't verify your account (connection timed out). Please try again.",
          isSuccess: false,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      final role = UserRoleX.fromValue(doc.data()?['role'] as String?);

      if (role == null) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        showTopBanner(
          context,
          "We couldn't find your account details. Please try signing up again "
          "or contact support.",
          isSuccess: false,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (role != UserRole.owner) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        showTopBanner(
          context,
          'This account is registered as ${role.label}. Please use the ${role.label} login instead.',
          isSuccess: false,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (!mounted) return;

      showTopBanner(context, 'Signed in successfully!', isSuccess: true);

      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        slideFadeRoute(const OwnerMainNavPage()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showTopBanner(context, signInErrorMessage(e.code), isSuccess: false);
    } catch (e) {
      if (!mounted) return;
      showTopBanner(context, 'Something went wrong. Please try again.', isSuccess: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      showTopBanner(context, 'Enter your email above first, then tap this.', isSuccess: false);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      showTopBanner(context, 'Password reset email sent.', isSuccess: true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      showTopBanner(context, signInErrorMessage(e.code), isSuccess: false);
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
                  'Sign In',
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
                          'Welcome Back',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 10),
                        const AuthRoleBadge(icon: Icons.storefront_rounded, label: 'Coffee Shop Owner'),
                        const SizedBox(height: 12),
                        const Text(
                          'Sign in to manage your coffee shop',
                          style: TextStyle(color: AppColors.textGrey, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
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
                        const SizedBox(height: 20),
                        AuthPasswordField(
                          label: 'Password',
                          controller: _passwordController,
                          hint: 'Enter your password',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter your password';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Side by side, or stacked on narrow phones / large fonts.
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    activeColor: AppColors.primaryBrown,
                                    onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Remember me', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                              ],
                            ),
                            TextButton(
                              onPressed: _handleForgotPassword,
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(color: AppColors.primaryBrown, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        AuthSubmitButton(
                          label: 'Sign In',
                          isLoading: _isLoading,
                          onPressed: _handleSignIn,
                        ),
                        const SizedBox(height: 16),
                        AuthSwitchRow(
                          question: "Don't have an account? ",
                          actionLabel: 'Sign Up',
                          onTap: () => Navigator.pushReplacement(context, slideUpRoute(const BusinessSignUpPage())),
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