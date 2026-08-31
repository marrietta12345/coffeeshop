import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'choose_account_type_page.dart';
import '../utils/page_transitions.dart';

/// Splash-style welcome screen: full-bleed background photo, centered
/// logo + script-style wordmark, tagline, a pill-shaped CTA, and
/// decorative onboarding dots. Uses AppTextStyles so the wordmark and
/// link text match ChooseAccountTypePage exactly.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // Responsive values — the SAME horizontal-padding formula is reused
    // on ChooseAccountTypePage so both screens feel like one continuous
    // flow rather than two differently-proportioned pages.
    final logoSize = (screenWidth * 0.34).clamp(110.0, 170.0);
    final horizontalPadding = (screenWidth * 0.08).clamp(24.0, 40.0);
    final wordmarkFontSize = (screenWidth * 0.115).clamp(34.0, 52.0);
    final taglineFontSize = (screenWidth * 0.037).clamp(13.0, 16.0);
    final buttonFontSize = (screenWidth * 0.04).clamp(15.0, 18.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/images/coffee_background.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.darkBackground,
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black38, Colors.black87],
                stops: [0.3, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Image.asset(
                    'lib/images/kafelo_logo.png',
                    width: logoSize,
                    height: logoSize,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Text(
                    'Kafelo',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.wordmark(fontSize: wordmarkFontSize, color: Colors.white),
                  ),
                  SizedBox(height: screenHeight * 0.018),
                  Text(
                    'Discover local coffee shops\naround Butuan City.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.tagline(fontSize: taglineFontSize, color: Colors.white70),
                  ),
                  const Spacer(flex: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBrown,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          slideFadeRoute(const ChooseAccountTypePage()),
                        );
                      },
                      child: Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.035),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}