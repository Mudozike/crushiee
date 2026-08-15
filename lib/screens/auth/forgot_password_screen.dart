import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../widgets/crushie_logo.dart';
import '../../widgets/gradient_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final VoidCallback onPasswordResetSuccess;
  final VoidCallback onSignInTap;
  final VoidCallback? onBack;

  const ForgotPasswordScreen({
    Key? key,
    required this.onPasswordResetSuccess,
    required this.onSignInTap,
    this.onBack,
  }) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _step = 1; // 1 = Enter Email, 2 = Verify Code & Set New Password
  bool _isLoading = false;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Real-time password validation criteria
  bool get _hasMinLength8 => _newPasswordController.text.length >= 8;
  bool get _hasUppercase => _newPasswordController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _newPasswordController.text.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _newPasswordController.text.contains(RegExp(r'[0-9]'));
  bool get _hasSpecialChar => _newPasswordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

  bool get _isPasswordFullyValid =>
      _hasMinLength8 && _hasUppercase && _hasLowercase && _hasDigit && _hasSpecialChar;

  bool get _isStep1Valid =>
      _emailController.text.contains('@') && _emailController.text.trim().length > 3;

  bool get _isCodeValid => _codeController.text.trim().length == 6;

  bool get _doPasswordsMatch =>
      _newPasswordController.text.isNotEmpty &&
      _newPasswordController.text == _confirmPasswordController.text;

  bool get _isStep2Valid => _isCodeValid && _isPasswordFullyValid && _doPasswordsMatch;

  int get _passwordScore {
    int score = 0;
    if (_hasMinLength8) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasDigit) score++;
    if (_hasSpecialChar) score++;
    return score;
  }

  String get _strengthLabel {
    if (_newPasswordController.text.isEmpty) return '';
    if (_passwordScore <= 2) return 'Weak';
    if (_passwordScore == 3) return 'Fair';
    if (_passwordScore == 4) return 'Good';
    return 'Strong';
  }

  Color get _strengthColor {
    if (_passwordScore <= 2) return Colors.red;
    if (_passwordScore == 3) return Colors.orange;
    if (_passwordScore == 4) return Colors.amber.shade700;
    return Colors.green;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_step == 2) {
          setState(() => _step = 1);
          return false;
        }
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
              if (_step == 2) {
                setState(() => _step = 1);
              } else if (widget.onBack != null) {
                widget.onBack!();
              } else {
                Navigator.maybePop(context);
              }
            },
          ),
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 1. Header: Crushie Logo (85px)
                          const CrushieLogo(
                            size: 85,
                            showShadow: true,
                          ),
                          const SizedBox(height: 20),

                          // Heading
                          Text(
                            _step == 1 ? 'Forgot Password' : 'Set New Password',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            _step == 1
                                ? 'Enter your account email address. We will send you a 6-digit reset code.'
                                : 'Enter the 6-digit code sent to your email and your new password.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          if (_step == 1) ...[
                            // Step 1: Email Input Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Send Reset Code Button
                            GradientButton(
                              text: 'Send Reset Code',
                              height: 56,
                              isLoading: _isLoading,
                              onPressed: _isStep1Valid
                                  ? () async {
                                      setState(() => _isLoading = true);
                                      await Future.delayed(const Duration(milliseconds: 600));
                                      if (mounted) {
                                        setState(() {
                                          _isLoading = false;
                                          _step = 2;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '6-digit reset code sent to ${_emailController.text.trim()}',
                                            ),
                                            backgroundColor: AppColors.primary,
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ] else ...[
                            // Step 2: 6-Digit Reset Code Field
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                fontSize: 18,
                                letterSpacing: 6,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: '6-Digit Reset Code',
                                counterText: '',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                prefixIcon: const Icon(Icons.pin, color: AppColors.primary),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // New Password Field
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureNewPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Live Password Validation Checkmarks & Strength Meter
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_newPasswordController.text.isNotEmpty) ...[
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Password Strength',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          _strengthLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: _strengthColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _passwordScore / 5.0,
                                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                        valueColor: AlwaysStoppedAnimation<Color>(_strengthColor),
                                        minHeight: 5,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],

                                  _buildCheckmarkRow('At least 8 characters', _hasMinLength8),
                                  const SizedBox(height: 4),
                                  _buildCheckmarkRow('One uppercase letter', _hasUppercase),
                                  const SizedBox(height: 4),
                                  _buildCheckmarkRow('One lowercase letter', _hasLowercase),
                                  const SizedBox(height: 4),
                                  _buildCheckmarkRow('One number', _hasDigit),
                                  const SizedBox(height: 4),
                                  _buildCheckmarkRow('One special character (!@#\$%)', _hasSpecialChar),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Confirm New Password Field
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                prefixIcon: const Icon(Icons.lock_reset, color: AppColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Update Password Button (Disabled until form is valid)
                            GradientButton(
                              text: 'Update Password',
                              height: 56,
                              isLoading: _isLoading,
                              onPressed: _isStep2Valid
                                  ? () async {
                                      setState(() => _isLoading = true);
                                      await Future.delayed(const Duration(milliseconds: 700));
                                      if (mounted) {
                                        setState(() => _isLoading = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Password updated successfully! Please sign in.'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                        widget.onPasswordResetSuccess();
                                      }
                                    }
                                  : null,
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Footer: Remember your password? Sign In
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Remember your password? ',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontSize: 14.5,
                                ),
                              ),
                              GestureDetector(
                                onTap: widget.onSignInTap, // DIRECT TO SIGN IN
                                child: const Text(
                                  'Sign In',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
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

  Widget _buildCheckmarkRow(String text, bool isSatisfied) {
    return Row(
      children: [
        Icon(
          isSatisfied ? Icons.check_circle : Icons.circle_outlined,
          size: 16,
          color: isSatisfied ? Colors.green : Colors.grey.shade400,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSatisfied ? FontWeight.bold : FontWeight.normal,
            color: isSatisfied
                ? Colors.green
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}
