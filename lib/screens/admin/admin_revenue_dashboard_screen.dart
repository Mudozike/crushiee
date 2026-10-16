import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../config/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../services/firestore_service.dart';

class AdminRevenueDashboardScreen extends StatelessWidget {
  const AdminRevenueDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final firestoreService = FirestoreService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Revenue Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {},
            tooltip: 'Refresh Revenue Data',
          ),
        ],
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: firestoreService.getAdminTransactionsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final transactions = snapshot.data ?? [];

          // Revenue analytics calculations
          double totalRevenue = 0.0;
          double connectionRevenue = 0.0;
          double premiumRevenue = 0.0;
          double verifiedRevenue = 0.0;
          double boostRevenue = 0.0;

          for (final tx in transactions) {
            if (tx.status == 'completed' || tx.status == 'success') {
              totalRevenue += tx.amount;
              final t = tx.type.toLowerCase();
              if (t.contains('conn')) {
                connectionRevenue += tx.amount;
              } else if (t.contains('prem')) {
                premiumRevenue += tx.amount;
              } else if (t.contains('ver') || t.contains('bundle')) {
                verifiedRevenue += tx.amount;
              } else if (t.contains('boost')) {
                boostRevenue += tx.amount;
              } else {
                connectionRevenue += tx.amount;
              }
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Total Revenue Card
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'Total Gross Revenue',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'KES ${totalRevenue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${transactions.length} Total Completed Transactions',
                        style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Category Revenue Breakdown Grid
                Text(
                  'Revenue by Category',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    _buildMetricCard(
                      context: context,
                      title: 'Connections',
                      amount: connectionRevenue,
                      icon: Icons.link,
                      color: Colors.green,
                    ),
                    _buildMetricCard(
                      context: context,
                      title: 'Premium',
                      amount: premiumRevenue,
                      icon: Icons.star,
                      color: AppColors.primary,
                    ),
                    _buildMetricCard(
                      context: context,
                      title: 'Verification',
                      amount: verifiedRevenue,
                      icon: Icons.verified,
                      color: AppColors.verifiedBlue,
                    ),
                    _buildMetricCard(
                      context: context,
                      title: 'Post Boosts',
                      amount: boostRevenue,
                      icon: Icons.bolt,
                      color: AppColors.boostOrange,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Recent Transactions Log
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Real-Time Transactions Log',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Chip(
                      label: Text('${transactions.length} items', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (transactions.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text(
                        'No transactions recorded yet.',
                        style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final tx = transactions[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(tx.type).withOpacity(0.12),
                          child: Icon(_getCategoryIcon(tx.type), color: _getCategoryColor(tx.type), size: 20),
                        ),
                        title: Text(
                          _formatTypeTitle(tx.type),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          'Ref: ${tx.paymentReference.length > 16 ? tx.paymentReference.substring(0, 16) : tx.paymentReference} • ${tx.paymentMethod.toUpperCase()}',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '+ KES ${tx.amount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.green),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeago.format(tx.createdAt, locale: 'en_short'),
                              style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required String title,
    required double amount,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            'KES ${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTypeTitle(String type) {
    switch (type.toLowerCase()) {
      case 'connection':
        return 'Connection Unlock';
      case 'premium':
        return 'Premium Subscription';
      case 'verified':
      case 'verification':
        return 'Verified Badge';
      case 'bundle':
        return 'Premium + Verified Bundle';
      case 'boost':
        return 'Post Boost';
      default:
        return type.toUpperCase();
    }
  }

  IconData _getCategoryIcon(String type) {
    switch (type.toLowerCase()) {
      case 'connection':
        return Icons.link;
      case 'premium':
        return Icons.star;
      case 'verified':
      case 'verification':
      case 'bundle':
        return Icons.verified;
      case 'boost':
        return Icons.bolt;
      default:
        return Icons.payment;
    }
  }

  Color _getCategoryColor(String type) {
    switch (type.toLowerCase()) {
      case 'connection':
        return Colors.green;
      case 'premium':
        return AppColors.primary;
      case 'verified':
      case 'verification':
      case 'bundle':
        return AppColors.verifiedBlue;
      case 'boost':
        return AppColors.boostOrange;
      default:
        return Colors.purple;
    }
  }
}
