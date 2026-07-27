import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../config/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/paystack_service.dart';
import '../../widgets/gradient_button.dart';

class PremiumSubscriptionScreen extends StatelessWidget {
  final VoidCallback onSubscriptionSuccess;

  const PremiumSubscriptionScreen({
    Key? key,
    required this.onSubscriptionSuccess,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final user = authProv.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crushie Premium'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 52),
                    const SizedBox(height: 10),
                    const Text(
                      'Crushie Premium',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'KES 200 / Month',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Text(
                'Premium Benefits',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),

              _buildFeatureRow('Unlimited Connections', 'Connect for FREE without paying KES 50 per connection.', Icons.all_inclusive, Colors.pink),
              _buildFeatureRow('Unlimited Messaging', 'Chat freely with all your connections.', Icons.chat_bubble, Colors.purple),
              _buildFeatureRow('No Ads', 'Enjoy a 100% ad-free experience.', Icons.block, Colors.green),
              _buildFeatureRow('See Profile Visitors', 'Know who viewed your profile.', Icons.visibility, Colors.blue),
              _buildFeatureRow('Priority Search Placement', 'Rank at the top of search & feed.', Icons.trending_up, Colors.orange),
              _buildFeatureRow('Advanced Filters', 'Filter by exact age, location & activity.', Icons.tune, Colors.indigo),
              _buildFeatureRow('Premium Crown Badge', 'Stand out with a gold PRO badge.', Icons.workspace_premium, Colors.amber),

              const SizedBox(height: 32),

              // Subscribe CTA Button
              GradientButton(
                text: 'SUBSCRIBE FOR KES 200/MONTH',
                onPressed: () async {
                  final result = await PaystackService.showPaymentDialog(
                    context: context,
                    title: 'Crushie Premium Subscription',
                    description: 'Monthly recurring subscription of KES 200 for unlimited connections & premium perks.',
                    amountKES: AppConstants.premiumMonthlyKES,
                    userEmail: user?.email ?? 'user@crushie.app',
                  );

                  if (result != null && result.success) {
                    authProv.upgradeToPremium();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Welcome to Crushie Premium! 🎉 Unlimited Connections active.')),
                    );
                    onSubscriptionSuccess();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, String subtitle, IconData icon, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
