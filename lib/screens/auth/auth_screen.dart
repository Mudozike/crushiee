import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/terms_and_conditions_modal.dart';
import 'email_verification_screen.dart';
import 'forgot_password_screen.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthComplete;

  const AuthScreen({
    Key? key,
    required this.onAuthComplete,
  }) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isSignUp = false;

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _is18PlusAccepted = false;
  bool _isTermsAccepted = false;
  bool _obscurePassword = true;

  bool _isPasswordCompliant(String password) {
    if (password.length < 6) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    return true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'Create Account' : 'Welcome Back'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle Tab Buttons (Sign Up vs Login)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUp = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isSignUp ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                'Log In',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: !_isSignUp ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isSignUp = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isSignUp ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Center(
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _isSignUp ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Username (Sign Up Only)
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a username' : null,
                  ),
                  const SizedBox(height: 16),
                ],

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined, color: AppColors.primary),
                  ),
                  validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email address' : null,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    helperText: _isSignUp ? 'At least 6 chars, 1 uppercase, 1 lowercase, 1 special char' : null,
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (_isSignUp && !_isPasswordCompliant(v)) {
                      return 'Password must have 6+ chars, 1 uppercase, 1 lowercase, 1 special char';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Confirm Password (Sign Up Only)
                if (_isSignUp) ...[
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscurePassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_reset, color: AppColors.primary),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // 18+ Checkbox Rule
                  CheckboxListTile(
                    value: _is18PlusAccepted,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: const Text(
                      'I confirm I am 18 years of age or older (Under 18 not allowed).',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) => setState(() => _is18PlusAccepted = val ?? false),
                  ),

                  // Terms & Conditions Checkbox
                  CheckboxListTile(
                    value: _isTermsAccepted,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: const Text(
                      'I agree to the Terms of Service & Privacy Policy.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    onChanged: (val) => setState(() => _isTermsAccepted = val ?? false),
                  ),

                  // Read Terms Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => TermsAndConditionsModal.show(context),
                      icon: const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                      label: const Text('Read Terms & Conditions', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  // Forgot Password Button (Login Only)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(
                              onPasswordResetSuccess: () => Navigator.pop(context),
                              onSignInTap: () => Navigator.pop(context),
                            ),
                          ),
                        );
                      },
                      child: const Text('Forgot Password?', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Button (Sign Up / Log In)
                GradientButton(
                  text: _isSignUp ? 'Sign Up' : 'Log In',
                  onPressed: () async {
                    if (_isSignUp) {
                      if (!_is18PlusAccepted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You must confirm you are 18+ to sign up.')),
                        );
                        return;
                      }
                      if (!_isTermsAccepted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please accept the Terms & Conditions.')),
                        );
                        return;
                      }

                      if (_formKey.currentState!.validate()) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EmailVerificationScreen(
                              email: _emailController.text.trim(),
                              onVerificationSuccess: widget.onAuthComplete,
                            ),
                          ),
                        );
                      }
                    } else {
                      if (_formKey.currentState!.validate()) {
                        final success = await authProv.signInWithEmail(
                          _emailController.text.trim(),
                          _passwordController.text.trim(),
                        );
                        if (success) {
                          widget.onAuthComplete();
                        }
                      }
                    }
                  },
                ),
                const SizedBox(height: 20),

                // Divider Line
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),

                // Continue with Google Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final success = await authProv.signInWithGoogle();
                      if (success) {
                        widget.onAuthComplete();
                      }
                    },
                    icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.red),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
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
