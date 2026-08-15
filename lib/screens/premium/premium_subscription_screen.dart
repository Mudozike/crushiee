import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/database_service.dart';
import '../../services/paystack_service.dart';

class PremiumSubscriptionScreen extends StatefulWidget {
  final VoidCallback onSubscriptionSuccess;

  const PremiumSubscriptionScreen({
    Key? key,
    required this.onSubscriptionSuccess,
  }) : super(key: key);

  @override
  State<PremiumSubscriptionScreen> createState() => _PremiumSubscriptionScreenState();
}

class _PremiumSubscriptionScreenState extends State<PremiumSubscriptionScreen> {
  String _selectedPlan = 'bundle_monthly'; // 'premium_monthly' or 'bundle_monthly'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final dbService = DatabaseService();
    final user = authProv.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crushie Premium & Bundles'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
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
                  children: const [
                    Icon(Icons.star, color: Colors.amber, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'Crushie Unlimited VIP',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Unlimited Free Connections • Verified Badges • Priority Feed',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Select Package Plan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Plan 1: Premium + Verified Bundle (Best Value)
              _buildPlanCard(
                id: 'bundle_monthly',
                title: 'Premium + Verified Bundle',
                price: 'KES 250/month',
                badgeText: 'BEST VALUE',
                badgeColor: AppColors.primary,
                subtitle: 'Includes Unlimited Free Connections + Verified Blue Checkmark Badge',
              ),
              const SizedBox(height: 10),

              // Plan 2: Premium Only
              _buildPlanCard(
                id: 'premium_monthly',
                title: 'Premium Only (Monthly)',
                price: 'KES 200/month',
                subtitle: 'Unlimited free connections, priority search placement, ad-free experience',
              ),
              const SizedBox(height: 24),

              Text(
                'Included Benefits',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _buildFeatureRow('Unlimited Connections', 'Connect for FREE without paying KES 50 per connection.', Icons.all_inclusive, Colors.pink),
              _buildFeatureRow('Verified Blue Checkmark', 'Earn trust & authentic verification badge (Bundle plan).', Icons.verified, AppColors.verifiedBlue),
              _buildFeatureRow('Unlimited Messaging', 'Chat freely with all your connections.', Icons.chat_bubble, Colors.purple),
              _buildFeatureRow('Priority Placement', 'Rank at the top of feeds & search.', Icons.trending_up, Colors.orange),

              const SizedBox(height: 28),

              // Subscribe CTA Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (user == null) return;

                    double amount = 250.0;
                    String desc = 'Premium + Verified Bundle Monthly';
                    String type = 'bundle';
                    int days = 30;

                    if (_selectedPlan == 'premium_monthly') {
                      amount = 200.0;
                      desc = 'Crushie Premium Monthly';
                      type = 'premium';
                      days = 30;
                    }

                    final res = await PaystackService.showPaymentDialog(
                      context: context,
                      title: 'Subscribe via Paystack',
                      description: desc,
                      amountKES: amount,
                      userEmail: user.email,
                    );

                    if (res != null && res.success) {
                      dbService.recordTransaction(
                        TransactionModel(
                          id: res.transactionId,
                          userId: user.id,
                          type: type,
                          amount: amount,
                          paymentReference: res.transactionId,
                          status: 'success',
                        ),
                      );

                      if (type == 'bundle') {
                        dbService.upgradeUserToBundle(user.id, days: days);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🎉 Premium + Verified Bundle Activated!')),
                        );
                      } else {
                        dbService.upgradeUserToPremium(user.id, days: days);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('🎉 Welcome to Crushie Premium! Unlimited Connections active.')),
                        );
                      }

                      authProv.refreshUser();
                      widget.onSubscriptionSuccess();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text(
                        'SUBSCRIBE VIA PAYSTACK',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard({
    required String id,
    required String title,
    required String price,
    String? subtitle,
    String? badgeText,
    Color? badgeColor,
  }) {
    final isSelected = _selectedPlan == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : (isDark ? AppColors.darkCard : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: id,
              groupValue: _selectedPlan,
              onChanged: (val) {
                if (val != null) setState(() => _selectedPlan = val);
              },
              activeColor: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badgeText != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor ?? AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String title, String subtitle, IconData icon, Color accent) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
