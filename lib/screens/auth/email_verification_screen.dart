import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/crushie_logo.dart';
import '../../widgets/gradient_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final VoidCallback onVerificationSuccess;
  final VoidCallback? onBack;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.onVerificationSuccess,
    this.onBack,
  }) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;

  void _verifyAndContinue() {
    setState(() => _isChecking = true);

    // Immediately advance to Profile Setup screen
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _isChecking = false);
        widget.onVerificationSuccess();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (widget.onBack != null) {
          widget.onBack!();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(),

                // Original Crushie Logo
                const CrushieLogo(
                  size: 90,
                  showShadow: true,
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                // Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'We have sent a verification email to your inbox. Please verify your email before continuing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Text(
                  widget.email,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),

                const Spacer(),

                // Button 1: I've Verified (Navigates to Profile Setup Screen)
                GradientButton(
                  text: 'I\'ve Verified',
                  isLoading: _isChecking,
                  onPressed: _verifyAndContinue,
                ),
                const SizedBox(height: 16),

                // Button 2: Resend Email
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Verification email resent to ${widget.email}'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    icon: Icon(
                      Icons.email_outlined,
                      color: isDark ? Colors.white : AppColors.primary,
                      size: 20,
                    ),
                    label: Text(
                      'Resend Email',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
