import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/paystack_service.dart';

class BoostPostModal extends StatefulWidget {
  final PostModel post;
  final UserModel currentUser;

  const BoostPostModal({
    Key? key,
    required this.post,
    required this.currentUser,
  }) : super(key: key);

  static void show(BuildContext context, PostModel post, UserModel currentUser) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BoostPostModal(post: post, currentUser: currentUser),
    );
  }

  @override
  State<BoostPostModal> createState() => _BoostPostModalState();
}

class _BoostPostModalState extends State<BoostPostModal> {
  String _selectedOption = '24h'; // '24h' or '7d'

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dbService = DatabaseService();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bolt, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boost Your Post',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    const Text(
                      'Pin your post to the top of the feed for up to 10x more crushes & connections.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Options
          _buildOptionTile(
            id: '24h',
            title: 'Boost for 24 Hours',
            price: 'KES 49',
            subtitle: 'Priority placement for a full 24-hour cycle',
          ),
          const SizedBox(height: 12),

          _buildOptionTile(
            id: '7d',
            title: 'Boost for 7 Days',
            price: 'KES 199',
            badgeText: 'BEST VALUE - SAVE KES 144',
            badgeColor: Colors.purple,
            subtitle: 'Top placement for a full 7 days',
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                double amount = 49.0;
                int hours = 24;
                String desc = 'Boost Post for 24 Hours';

                if (_selectedOption == '7d') {
                  amount = 199.0;
                  hours = 24 * 7;
                  desc = 'Boost Post for 7 Days';
                }

                Navigator.pop(context);

                final res = await PaystackService.showPaymentDialog(
                  context: context,
                  title: 'Boost Post',
                  description: desc,
                  amountKES: amount,
                  userEmail: widget.currentUser.email,
                );

                if (res != null && res.success) {
                  dbService.recordTransaction(
                    TransactionModel(
                      id: res.transactionId,
                      userId: widget.currentUser.id,
                      type: 'boost',
                      amount: amount,
                      paymentReference: res.transactionId,
                      status: 'success',
                    ),
                  );

                  dbService.boostPost(widget.post.id, hours);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('⚡ Post Boosted Successfully! Your post is now pinned near the top of the feed.')),
                  );
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
                    'PAY TO BOOST VIA PAYSTACK',
                    style: TextStyle(
                      fontSize: 15,
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
    );
  }

  Widget _buildOptionTile({
    required String id,
    required String title,
    required String price,
    String? subtitle,
    String? badgeText,
    Color? badgeColor,
  }) {
    final isSelected = _selectedOption == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedOption = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : (isDark ? AppColors.darkSurface : Colors.grey.shade50),
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
              groupValue: _selectedOption,
              onChanged: (val) {
                if (val != null) setState(() => _selectedOption = val);
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
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
