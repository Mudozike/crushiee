import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class TermsAndConditionsModal extends StatelessWidget {
  const TermsAndConditionsModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const TermsAndConditionsModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.gavel, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '1. Age Requirement (Strictly 18+)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Crushie is exclusively designed for adults. You must be at least 18 years of age to register an account or access services on Crushie. Misrepresentation of age will result in permanent suspension.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  SizedBox(height: 14),

                  Text(
                    '2. Respectful Community & Safety',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'We strictly prohibit harassment, hate speech, scamming, impersonation, or illegal activity. Users violating community rules will be reported and permanently banned.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  SizedBox(height: 14),

                  Text(
                    '3. Connection Fees & Subscription Services',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Connection fees (KES 50) unlock private contact details for single connections. Premium Subscriptions (KES 200/mo) allow unlimited connection requests. Lifetime Verification badges (KES 499) verify genuine identity.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  SizedBox(height: 14),

                  Text(
                    '4. Privacy & Data Handling',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Your private contact information is protected and revealed only to users with whom a paid connection has been established. Crushie does not sell or share personal data to third parties.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(primary: AppColors.primary),
              child: const Text('I Understand & Agree', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
