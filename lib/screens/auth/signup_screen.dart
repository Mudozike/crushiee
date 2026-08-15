import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/crushie_logo.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../widgets/terms_and_conditions_modal.dart';

class SignUpScreen extends StatefulWidget {
  final Function(String email) onSignUpSuccess;
  final VoidCallback? onGoogleSignInSuccess;
  final VoidCallback onSignInTap;
  final VoidCallback? onBack;

  const SignUpScreen({
    Key? key,
    required this.onSignUpSuccess,
    this.onGoogleSignInSuccess,
    required this.onSignInTap,
    this.onBack,
  }) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool get _isPasswordValid => _passwordController.text.length >= 6;

  bool get _isEmailValid =>
      _emailController.text.contains('@') && _emailController.text.trim().length > 3;

  bool get _doPasswordsMatch =>
      _passwordController.text.isNotEmpty &&
      _passwordController.text == _confirmPasswordController.text;

  bool get _isFormReady => _isEmailValid && _isPasswordValid && _doPasswordsMatch;

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
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);

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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1. Header: Crushie Logo
                            const CrushieLogo(
                              size: 90,
                              showShadow: true,
                            ),
                            const SizedBox(height: 18),

                            // Heading: Create Your Account
                            Text(
                              'Create Your Account',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),

                            ShaderMask(
                              shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                              child: const Text(
                                'Your next meaningful connection starts here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // 2. Authentication: Continue with Google
                            GoogleSignInButton(
                              text: 'Continue with Google',
                              onPressed: () async {
                                final success = await authProv.signInWithGoogle();
                                if (success) {
                                  if (widget.onGoogleSignInSuccess != null) {
                                    widget.onGoogleSignInSuccess!();
                                  } else {
                                    widget.onSignUpSuccess(_emailController.text.trim());
                                  }
                                }
                              },
                            ),
                            const SizedBox(height: 20),

                            // Divider: "OR"
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Email Address
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
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.red, width: 2),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
                            ),
                            const SizedBox(height: 16),

                            // Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.newPassword],
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                helperText: 'Password must be at least 6 characters.',
                                helperStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                                floatingLabelBehavior: FloatingLabelBehavior.auto,
                                prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.red, width: 2),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter a password';
                                if (v.length < 6) return 'Password must be at least 6 characters';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              autofillHints: const [AutofillHints.newPassword],
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
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
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.red, width: 1.2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: Colors.red, width: 2),
                                ),
                              ),
                              validator: (v) {
                                if (v != _passwordController.text) return 'Passwords do not match';
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),

                            // Create Account Button
                            GradientButton(
                              text: 'Create Account',
                              height: 56,
                              isLoading: authProv.isLoading,
                              onPressed: _isFormReady
                                  ? () async {
                                      if (_formKey.currentState!.validate()) {
                                        final email = _emailController.text.trim();
                                        final password = _passwordController.text.trim();
                                        final username = email.split('@').first;

                                        await authProv.signUpWithEmail(email, password, username);
                                        widget.onSignUpSuccess(email);
                                      }
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 24),

                            // Footer: Sign In Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    fontSize: 14.5,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: widget.onSignInTap,
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
                            const SizedBox(height: 14),

                            // Clickable Terms Disclaimer
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: GestureDetector(
                                onTap: () => TermsAndConditionsModal.show(context),
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 12,
                                      height: 1.4,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                    children: const [
                                      TextSpan(text: 'By creating an account, you agree to our '),
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
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
      ),
    );
  }
}
