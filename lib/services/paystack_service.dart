import 'dart:async';
import 'package:flutter/material.dart';
import '../config/app_colors.dart';

enum PaymentMethod { mpesa, airtel, card }

class PaymentResult {
  final bool success;
  final String transactionId;
  final String message;

  PaymentResult({
    required this.success,
    required this.transactionId,
    required this.message,
  });
}

class PaystackService {
  static const String _paystackPublicKey = 'pk_test_crushie_paystack_key';

  // Process payment using bottom sheet modal dialog for M-PESA, Airtel, or Card
  static Future<PaymentResult?> showPaymentDialog({
    required BuildContext context,
    required String title,
    required String description,
    required double amountKES,
    required String userEmail,
  }) async {
    return showModalBottomSheet<PaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaystackPaymentSheet(
        title: title,
        description: description,
        amountKES: amountKES,
        userEmail: userEmail,
      ),
    );
  }
}

class _PaystackPaymentSheet extends StatefulWidget {
  final String title;
  final String description;
  final double amountKES;
  final String userEmail;

  const _PaystackPaymentSheet({
    Key? key,
    required this.title,
    required this.description,
    required this.amountKES,
    required this.userEmail,
  }) : super(key: key);

  @override
  State<_PaystackPaymentSheet> createState() => _PaystackPaymentSheetState();
}

class _PaystackPaymentSheetState extends State<_PaystackPaymentSheet> {
  PaymentMethod _selectedMethod = PaymentMethod.mpesa;
  final TextEditingController _phoneController = TextEditingController(text: '0712345678');
  final TextEditingController _cardController = TextEditingController(text: '4242 4242 4242 4242');
  final TextEditingController _expiryController = TextEditingController(text: '12/28');
  final TextEditingController _cvvController = TextEditingController(text: '123');
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header handle
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

          // Title & Brand logo
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.payment, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    Text(
                      'Secured by Paystack',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'KES ${widget.amountKES.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Payment Methods Selector
          Text(
            'Select Payment Method',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildMethodTab(PaymentMethod.mpesa, 'M-PESA', Icons.phone_android, Colors.green),
              const SizedBox(width: 8),
              _buildMethodTab(PaymentMethod.airtel, 'Airtel', Icons.cell_tower, Colors.red),
              const SizedBox(width: 8),
              _buildMethodTab(PaymentMethod.card, 'Card', Icons.credit_card, AppColors.secondary),
            ],
          ),
          const SizedBox(height: 20),

          // Form fields based on selected method
          if (_selectedMethod == PaymentMethod.mpesa || _selectedMethod == PaymentMethod.airtel) ...[
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: _selectedMethod == PaymentMethod.mpesa
                    ? 'M-PESA Phone Number'
                    : 'Airtel Money Phone Number',
                prefixIcon: const Icon(Icons.phone),
                hintText: '07XX XXX XXX',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'An M-PESA STK Push prompt will be sent to your phone to authorize KES ${widget.amountKES.toStringAsFixed(0)}.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ] else ...[
            TextField(
              controller: _cardController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Card Number',
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _expiryController,
                    decoration: const InputDecoration(
                      labelText: 'MM/YY',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _cvvController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'CVV',
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),

          // Pay Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _processPayment,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  alignment: Alignment.center,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          'PAY KES ${widget.amountKES.toStringAsFixed(0)} NOW',
                          style: const TextStyle(
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
    );
  }

  Widget _buildMethodTab(PaymentMethod method, String label, IconData icon, Color accentColor) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = method),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? accentColor : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? accentColor : Colors.grey, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? accentColor : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processPayment() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));

    final txId = 'PAYSTACK_${DateTime.now().millisecondsSinceEpoch}';
    Navigator.of(context).pop(
      PaymentResult(
        success: true,
        transactionId: txId,
        message: 'Payment of KES ${widget.amountKES.toStringAsFixed(0)} successful!',
      ),
    );
  }
}
