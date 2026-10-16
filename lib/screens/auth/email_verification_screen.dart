import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/crushie_logo.dart';
import '../../widgets/gradient_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final VoidCallback onVerificationSuccess;
  final VoidCallback? onBack;
  final VoidCallback? onSignOut;

  const EmailVerificationScreen({
    Key? key,
    required this.email,
    required this.onVerificationSuccess,
    this.onBack,
    this.onSignOut,
  }) : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  DateTime? _lastResendAt;

  Future<void> _verifyAndContinue() async {
    if (_isChecking || _isResending) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isChecking = true);
    final authProv = Provider.of<AuthProvider>(context, listen: false);

    final isVerified = await authProv.checkEmailVerified();

    if (mounted) {
      setState(() => _isChecking = false);
      if (isVerified) {
        widget.onVerificationSuccess();
      } else {
        final errorMsg = authProv.errorMessage;
        final isNetwork = authProv.errorCode == 'network-request-failed' ||
            (errorMsg != null && errorMsg.toLowerCase().contains('network'));

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isNetwork
                  ? (errorMsg ??
                      'Network error. Please check your internet connection.')
                  : 'Your email is not verified yet. Please check your inbox, tap the verification link, then tap "I\'ve Verified My Account".',
            ),
            backgroundColor:
                isNetwork ? Colors.red.shade700 : Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_isResending || _isChecking) return;
    final messenger = ScaffoldMessenger.of(context);

    if (_lastResendAt != null &&
        DateTime.now().difference(_lastResendAt!) <
            const Duration(seconds: 30)) {
      final remaining =
          30 - DateTime.now().difference(_lastResendAt!).inSeconds;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Please wait $remaining seconds before requesting another email.'),
          backgroundColor: Colors.amber.shade900,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isResending = true);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProv.resendVerificationEmail();
    _lastResendAt = DateTime.now();

    if (mounted) {
      setState(() => _isResending = false);
      if (success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Verification email sent to ${widget.email}'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
                authProv.errorMessage ?? 'Failed to send verification email.'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleExit() {
    if (widget.onSignOut != null) {
      widget.onSignOut!();
    } else if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        _handleExit();
        return false;
      },
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDark ? Colors.white : Colors.black87),
            onPressed: (_isChecking || _isResending) ? null : _handleExit,
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight > 40
                        ? constraints.maxHeight - 40
                        : 0,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(),

                        // Original Crushie Logo
                        const CrushieLogo(
                          size: 90,
                          showShadow: true,
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'Verify Your Email',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
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
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
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
                        const SizedBox(height: 24),

                        // Button 1: I've Verified (Checks Firebase currentUser.emailVerified)
                        GradientButton(
                          text: 'I\'ve Verified My Account',
                          isLoading: _isChecking,
                          onPressed: _isResending ? null : _verifyAndContinue,
                        ),
                        const SizedBox(height: 16),

                        // Button 2: Resend Email
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: (_isResending || _isChecking)
                                ? null
                                : _resendEmail,
                            icon: _isResending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary),
                                  )
                                : Icon(
                                    Icons.email_outlined,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.primary,
                                    size: 20,
                                  ),
                            label: Text(
                              _isResending
                                  ? 'Sending...'
                                  : 'Resend Verification Email',
                              style: TextStyle(
                                color:
                                    isDark ? Colors.white : AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark
                                    ? AppColors.darkBorder
                                    : AppColors.lightBorder,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Button 3: Safe Sign Out / Switch Account
                        TextButton.icon(
                          onPressed: (_isChecking || _isResending)
                              ? null
                              : _handleExit,
                          icon: Icon(
                            Icons.logout,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          label: Text(
                            'Sign Out / Change Account',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
