import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/crushie_logo.dart';
import '../../widgets/gradient_button.dart';

class LandingScreen extends StatefulWidget {
  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  const LandingScreen({
    Key? key,
    required this.onGetStarted,
    required this.onSignIn,
  }) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(height: 12),

                          // Top Branding Section (Logo + App Name + Slogan + Description)
                          Column(
                            children: [
                              const SizedBox(height: 24),

                              // Crushie Logo (Prominent 145px)
                              const CrushieLogo(
                                size: 145,
                                showShadow: true,
                              ),
                              const SizedBox(height: 20),

                              // App Name "Crushie"
                              Text(
                                'Crushie',
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Slogan: "Crush. Match. Connect."
                              ShaderMask(
                                shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                                child: const Text(
                                  'Crush. Match. Connect.',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),

                              // Description: "Meet people who match your energy and build meaningful conversations."
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Meet people who match your energy and build meaningful conversations.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? const Color(0xFFB3B3B3)
                                        : const Color(0xFF4A4A4A),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          // Bottom Action Section (Get Started Button + Sign In Link)
                          Column(
                            children: [
                              // Large rounded Get Started button -> Navigates to Sign Up Screen
                              GradientButton(
                                text: 'Get Started',
                                height: 58,
                                onPressed: widget.onGetStarted,
                              ),
                              const SizedBox(height: 20),

                              // "Already have an account? Sign In" -> Navigates directly to Sign In Screen
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: widget.onSignIn,
                                    child: const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
