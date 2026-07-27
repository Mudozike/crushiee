import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/paystack_service.dart';
import '../../widgets/gradient_button.dart';

class VerificationScreen extends StatefulWidget {
  final VoidCallback onVerifiedSuccess;

  const VerificationScreen({
    Key? key,
    required this.onVerifiedSuccess,
  }) : super(key: key);

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  bool _selfieUploaded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final user = authProv.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Verified'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: AppColors.verifiedBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified, color: Colors.white, size: 48),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Verified Profile Badge',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Show people on Crushie that your profile is authentic.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Benefits
              _buildBenefitItem('Verified Badge', 'Blue checkmark on your profile & posts.', Icons.check_circle, AppColors.verifiedBlue),
              _buildBenefitItem('Trusted Profile', 'Get up to 3x more connection requests.', Icons.security, Colors.green),
              _buildBenefitItem('Higher Placement', 'Appear higher in Discover & Community feeds.', Icons.trending_up, AppColors.primary),
              const SizedBox(height: 28),

              // Upload Selfie Step
              Text(
                'Step 1: Upload Verification Selfie',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _selfieUploaded = true),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selfieUploaded ? Colors.green : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      width: _selfieUploaded ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: _selfieUploaded
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.check_circle, color: Colors.green, size: 24),
                              SizedBox(width: 8),
                              Text('Selfie Uploaded Ready!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.camera_alt_outlined, size: 36, color: AppColors.primary),
                              SizedBox(height: 6),
                              Text('Tap to take verification photo', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: const Text(
                  'Note: Profile verification requires a one-time fee of KES 499 for a lifetime badge. Verification does NOT include Premium Membership.',
                  style: TextStyle(fontSize: 12, color: Colors.amber),
                ),
              ),
              const SizedBox(height: 28),

              // Pay & Verify Button
              GradientButton(
                text: 'Pay KES 499 & Verify (Lifetime)',
                onPressed: () async {
                  if (!_selfieUploaded) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please upload a verification selfie first!')),
                    );
                    return;
                  }

                  final result = await PaystackService.showPaymentDialog(
                    context: context,
                    title: 'Lifetime Profile Verification Badge',
                    description: 'One-time KES 499 fee to activate your lifetime verified blue checkmark.',
                    amountKES: AppConstants.verificationFeeKES,
                    userEmail: user?.email ?? 'user@crushie.app',
                  );

                  if (result != null && result.success) {
                    authProv.verifyUser();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Congratulations! Your profile is now Verified! 🎉')),
                    );
                    widget.onVerifiedSuccess();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text(desc, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
