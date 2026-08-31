import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/page_transitions.dart';
import 'sign_in_page.dart';
import 'sign_up_page.dart';
import 'business_sign_in_page.dart';

/// Full-bleed page styled to feel like a direct continuation of
/// WelcomePage: same wordmark font, same link style, same responsive
/// padding formula, same brand accent color — so the two screens read as
/// one consistent flow instead of two different designs.
class ChooseAccountTypePage extends StatelessWidget {
  const ChooseAccountTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Same formula as WelcomePage, so padding feels identical between screens.
    final horizontalPadding = (screenWidth * 0.08).clamp(24.0, 40.0);
    final wordmarkFontSize = (screenWidth * 0.09).clamp(28.0, 40.0);
    final bodyFontSize = (screenWidth * 0.033).clamp(12.0, 14.0);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Same soft decorative blobs as the rest of the brand's dressed-up screens.
          Positioned(
            top: -60,
            right: -50,
            child: _SoftBlob(size: 220, color: AppColors.primaryBrown.withOpacity(0.08)),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: _SoftBlob(size: 200, color: AppColors.primaryBrown.withOpacity(0.05)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 8, horizontalPadding, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 2),
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AppColors.primaryBrown.withOpacity(0.9), AppColors.primaryBrown],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBrown.withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'lib/images/kafelo_logo.png',
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Kafelo',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.wordmark(fontSize: wordmarkFontSize, color: AppColors.primaryBrown),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 24, height: 1, color: const Color(0xFFE5E0DB)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text(
                                'Login or continue as',
                                style: AppTextStyles.bodyMuted(fontSize: bodyFontSize, color: AppColors.textGrey),
                              ),
                            ),
                            Container(width: 24, height: 1, color: const Color(0xFFE5E0DB)),
                          ],
                        ),
                        const Spacer(flex: 2),
                        _AccountTypeCard(
                          illustrationAsset: 'lib/images/customer.png',
                          background: const Color(0xFFF6EDE4),
                          accentColor: AppColors.primaryBrown,
                          title: 'Coffee Explorer',
                          description: 'Discover and explore coffee shops.',
                          onTap: () {
                            Navigator.push(context, slideUpRoute(const SignInPage()));
                          },
                        ),
                        const SizedBox(height: 16),
                        _AccountTypeCard(
                          illustrationAsset: 'lib/images/business_owner.png',
                          background: const Color(0xFFF1E5D8),
                          accentColor: const Color(0xFF7A5C3E),
                          title: 'Coffee Shop Owner',
                          description: 'Manage your coffee shop and information.',
                          onTap: () {
                            Navigator.push(context, slideUpRoute(const BusinessSignInPage()));
                          },
                        ),
                        const Spacer(flex: 4),
                        Container(height: 1, color: const Color(0xFFF0EDE9)),
                        const SizedBox(height: 18),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AppTextStyles.bodyMuted(fontSize: bodyFontSize, color: AppColors.textGrey),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, slideUpRoute(const SignUpPage()));
                              },
                              child: Text(
                                'Sign Up',
                                style: AppTextStyles.linkAccent(fontSize: bodyFontSize),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

/// A soft, blurred glow circle used as decorative depth behind content —
/// common in premium/modern app backgrounds without needing real images.
class _SoftBlob extends StatelessWidget {
  final double size;
  final Color color;

  const _SoftBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.inputFill,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, size: 20, color: AppColors.textDark),
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  final String illustrationAsset;
  final Color background;
  final Color accentColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.illustrationAsset,
    required this.background,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.14),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Illustration bleeds to the card edge, like the reference design.
            SizedBox(
              width: 84,
              height: 96,
              child: Image.asset(
                illustrationAsset,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: accentColor.withOpacity(0.15),
                  child: Icon(Icons.person_rounded, color: accentColor, size: 32),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: const Icon(Icons.chevron_right_rounded, color: AppColors.textGrey, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}