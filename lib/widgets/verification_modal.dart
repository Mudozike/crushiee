import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../config/app_colors.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/paystack_service.dart';

class VerificationModal extends StatefulWidget {
  final UserModel user;

  const VerificationModal({
    Key? key,
    required this.user,
  }) : super(key: key);

  static void show(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerificationModal(user: user),
    );
  }

  @override
  State<VerificationModal> createState() => _VerificationModalState();
}

class _VerificationModalState extends State<VerificationModal> {
  String _selectedOption = 'bundle_monthly'; // 'monthly', 'yearly', 'bundle_monthly'
  XFile? _selectedSelfieFile;
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  bool _isUploadingPhoto = false;

  Future<void> _pickVerificationPhoto(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (image != null) {
        setState(() {
          _selectedSelfieFile = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select photo: $e')),
      );
    }
  }

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
      child: SingleChildScrollView(
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
                    color: AppColors.verifiedBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Get Verified on Crushie',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const Text(
                        'Build authentic trust & boost your status',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Step 1: Verification Photo
            const Text(
              'Step 1: Upload Verification Photo',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.verifiedBlue),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedSelfieFile != null ? Colors.green : AppColors.verifiedBlue.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  if (_selectedSelfieFile == null) ...[
                    Row(
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: AppColors.verifiedBlue, size: 28),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Photo saved to: verification/{userId}/photo.jpg',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => _pickVerificationPhoto(ImageSource.camera),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.verifiedBlue),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: const Text('Camera', style: TextStyle(fontSize: 11.5)),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () => _pickVerificationPhoto(ImageSource.gallery),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.verifiedBlue),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          child: const Text('Gallery', style: TextStyle(fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Photo Selected: ${_selectedSelfieFile!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedSelfieFile = null),
                          child: const Text('Change', style: TextStyle(color: Colors.red, fontSize: 11.5)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Step 2: Options List
            const Text(
              'Step 2: Choose Plan',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 8),

            _buildOptionTile(
              id: 'bundle_monthly',
              title: 'Premium + Verified Bundle',
              price: 'KES 250/month',
              badgeText: 'BEST VALUE',
              badgeColor: AppColors.primary,
              subtitle: 'Includes Unlimited Free Connections + Verified Checkmark Badge',
            ),
            const SizedBox(height: 10),

            _buildOptionTile(
              id: 'monthly',
              title: 'Verification Only (Monthly)',
              price: 'KES 99/month',
              subtitle: 'Verified blue checkmark badge on profile',
            ),
            const SizedBox(height: 10),

            _buildOptionTile(
              id: 'yearly',
              title: 'Verification Only (Yearly)',
              price: 'KES 999/year',
              badgeText: 'SAVE 15%',
              badgeColor: Colors.orange,
              subtitle: 'Full 1-Year Verified blue checkmark badge',
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  if (_selectedSelfieFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please upload a verification selfie photo first!')),
                    );
                    return;
                  }

                  setState(() => _isUploadingPhoto = true);

                  final photoUrl = await _storageService.uploadVerificationPhoto(
                    userId: widget.user.id,
                    file: _selectedSelfieFile!,
                  );

                  setState(() => _isUploadingPhoto = false);

                  double amount = 99.0;
                  String desc = 'Verification Monthly Subscription';
                  String type = 'verification';
                  int days = 30;

                  if (_selectedOption == 'yearly') {
                    amount = 999.0;
                    desc = 'Verification Yearly Subscription';
                    days = 365;
                  } else if (_selectedOption == 'bundle_monthly') {
                    amount = 250.0;
                    desc = 'Premium + Verified Bundle Monthly';
                    type = 'bundle';
                    days = 30;
                  }

                  Navigator.pop(context);

                  final res = await PaystackService.showPaymentDialog(
                    context: context,
                    title: 'Get Verified',
                    description: desc,
                    amountKES: amount,
                    userEmail: widget.user.email,
                  );

                  if (res != null && res.success) {
                    dbService.recordTransaction(
                      TransactionModel(
                        id: res.transactionId,
                        userId: widget.user.id,
                        type: type,
                        amount: amount,
                        paymentReference: res.transactionId,
                        status: 'success',
                      ),
                    );

                    final updatedUser = dbService.getUser(widget.user.id)?.copyWith(
                      isVerified: true,
                      verifiedExpiry: DateTime.now().add(Duration(days: days)),
                      verificationPhoto: photoUrl,
                      isPremium: type == 'bundle' ? true : null,
                    );

                    if (updatedUser != null) {
                      dbService.updateUser(updatedUser);
                    }

                    if (type == 'bundle') {
                      dbService.upgradeUserToBundle(widget.user.id, days: days);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎉 Premium + Verified Bundle activated! Photo Saved.')),
                      );
                    } else {
                      dbService.verifyUser(widget.user.id, days: days);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎉 Congratulations! You are now Verified on Crushie!')),
                      );
                    }
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
                    child: Text(
                      _isUploadingPhoto ? 'UPLOADING PHOTO...' : 'PROCEED TO PAY VIA PAYSTACK',
                      style: const TextStyle(
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
}
