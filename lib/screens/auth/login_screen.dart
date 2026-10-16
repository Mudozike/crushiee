import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/crushie_logo.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final VoidCallback onSignUpTap;
  final VoidCallback onForgotPasswordTap;
  final VoidCallback? onBack;

  const LoginScreen({
    Key? key,
    required this.onLoginSuccess,
    required this.onSignUpTap,
    required this.onForgotPasswordTap,
    this.onBack,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  bool get _isFormReady =>
      _emailController.text.contains('@') &&
      _passwordController.text.isNotEmpty;

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
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDark ? Colors.white : Colors.black87),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                            // 1. Header: Crushie Logo (85px)
                            const CrushieLogo(
                              size: 85,
                              showShadow: true,
                            ),
                            const SizedBox(height: 20),

                            // Heading: Welcome Back
                            Text(
                              'Welcome Back',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Subtitle
                            Text(
                              'Sign in to continue connecting on Crushie.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 28),

                            // 2. Google Authentication
                            GoogleSignInButton(
                              text: 'Continue with Google',
                              onPressed: authProv.isLoading
                                  ? null
                                  : () async {
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final success =
                                          await authProv.signInWithGoogle();
                                      if (!mounted) return;

                                      if (success) {
                                        widget.onLoginSuccess();
                                      } else {
                                        if (authProv.errorMessage != null) {
                                          final errorMsg =
                                              authProv.errorMessage!;
                                          final isProviderConflict = authProv
                                                      .errorCode ==
                                                  'account-exists-with-different-credential' ||
                                              errorMsg.toLowerCase().contains(
                                                  'another sign-in method');

                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(errorMsg),
                                              backgroundColor:
                                                  Colors.red.shade700,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration:
                                                  const Duration(seconds: 5),
                                              action: isProviderConflict
                                                  ? SnackBarAction(
                                                      label: 'Reset',
                                                      textColor:
                                                          Colors.amberAccent,
                                                      onPressed: widget
                                                          .onForgotPasswordTap,
                                                    )
                                                  : null,
                                            ),
                                          );
                                        }
                                      }
                                    },
                            ),
                            const SizedBox(height: 20),

                            // Divider: Simply "OR"
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                      color: isDark
                                          ? AppColors.darkBorder
                                          : AppColors.lightBorder),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // 3. Email Address
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                prefixIcon: const Icon(Icons.email_outlined,
                                    color: AppColors.primary),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 1.2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 2),
                                ),
                              ),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Enter a valid email address'
                                  : null,
                            ),
                            const SizedBox(height: 16),

                            // 4. Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.lightTextPrimary,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.auto,
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: AppColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 16),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: isDark
                                        ? AppColors.darkBorder
                                        : AppColors.lightBorder,
                                    width: 1.2,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 1.2),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                      color: Colors.red, width: 2),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                            ),

                            // Forgot Password Link
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: widget.onForgotPasswordTap,
                                child: const Text(
                                  'Forgot password?',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // 5. Sign In Button
                            GradientButton(
                              text: 'Sign In',
                              height: 56,
                              isLoading: authProv.isLoading,
                              onPressed: (_isFormReady && !authProv.isLoading)
                                  ? () async {
                                      if (_formKey.currentState!.validate()) {
                                        final messenger =
                                            ScaffoldMessenger.of(context);
                                        final success =
                                            await authProv.signInWithEmail(
                                          _emailController.text.trim(),
                                          _passwordController.text.trim(),
                                        );
                                        if (!mounted) return;

                                        if (success) {
                                          widget.onLoginSuccess();
                                        } else {
                                          final errorMsg = authProv
                                                  .errorMessage ??
                                              'Sign in failed. Please try again.';
                                          final isUserNotFound = authProv
                                                      .errorCode ==
                                                  'user-not-found' ||
                                              errorMsg
                                                  .toLowerCase()
                                                  .contains('no account found');
                                          final isWrongPassword =
                                              authProv.errorCode ==
                                                      'wrong-password' ||
                                                  authProv.errorCode ==
                                                      'invalid-credential' ||
                                                  errorMsg
                                                      .toLowerCase()
                                                      .contains('incorrect');

                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(errorMsg),
                                              backgroundColor:
                                                  Colors.red.shade700,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              duration:
                                                  const Duration(seconds: 5),
                                              action: isUserNotFound
                                                  ? SnackBarAction(
                                                      label: 'Sign Up',
                                                      textColor:
                                                          Colors.amberAccent,
                                                      onPressed:
                                                          widget.onSignUpTap,
                                                    )
                                                  : isWrongPassword
                                                      ? SnackBarAction(
                                                          label: 'Reset',
                                                          textColor: Colors
                                                              .amberAccent,
                                                          onPressed: widget
                                                              .onForgotPasswordTap,
                                                        )
                                                      : null,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 28),

                            // 6. Footer: DIRECT NAVIGATION TO CREATE ACCOUNT (NO LANDING REDIRECT!)
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Don\'t have an account? ',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.lightTextSecondary,
                                    fontSize: 14.5,
                                  ),
                                ),
                                GestureDetector(
                                  onTap:
                                      widget.onSignUpTap, // DIRECT TO SIGN UP
                                  child: const Text(
                                    'Create Account',
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
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
