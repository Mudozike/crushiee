import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_colors.dart';
import '../../models/transaction_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/database_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
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
  String _selectedOption = 'bundle_monthly'; // 'monthly', 'yearly', 'bundle_monthly'
  XFile? _selectedSelfieFile;
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  bool _isUploadingPhoto = false;

  Future<void> _pickVerificationPhoto(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image != null) {
        final isUnder2MB = await _storageService.isPhotoUnder2MB(image);
        if (!isUnder2MB) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected photo exceeds 2MB limit. Please choose a smaller photo.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

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
    final authProv = Provider.of<AuthProvider>(context);
    final userProv = Provider.of<UserProvider>(context);
    final dbService = DatabaseService();
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
              const SizedBox(height: 16),
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
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Upload a selfie photo (< 2MB) to verify your identity & unlock your blue checkmark.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // STEP 1: Upload Photo First (< 2MB)
              Text(
                'Step 1: Upload Verification Photo (Max 2MB)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedSelfieFile != null ? Colors.green : AppColors.verifiedBlue.withOpacity(0.4),
                    width: _selectedSelfieFile != null ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    if (_selectedSelfieFile == null) ...[
                      const Icon(Icons.camera_alt_outlined, size: 44, color: AppColors.verifiedBlue),
                      const SizedBox(height: 8),
                      const Text(
                        'Saved to Firebase Storage: verification/{userId}/photo.jpg (Max 2MB)',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickVerificationPhoto(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Camera'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.verifiedBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickVerificationPhoto(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library, size: 18),
                              label: const Text('Gallery'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.verifiedBlue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 28),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Photo Selected (< 2MB Validated)',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13.5),
                                ),
                                Text(
                                  'File: ${_selectedSelfieFile!.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _selectedSelfieFile = null),
                            child: const Text('Change', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // STEP 2: Choose Verification Plan
              Text(
                'Step 2: Choose Verification Plan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Plan 1: Bundle (Best Value)
              _buildOptionCard(
                id: 'bundle_monthly',
                title: 'Premium + Verified Bundle',
                price: 'KES 250/month',
                badgeText: 'BEST VALUE',
                badgeColor: AppColors.primary,
                subtitle: 'Includes Unlimited Free Connections + Verified Blue Badge',
              ),
              const SizedBox(height: 10),

              // Plan 2: Monthly
              _buildOptionCard(
                id: 'monthly',
                title: 'Verification Only (Monthly)',
                price: 'KES 99/month',
                subtitle: 'Verified blue checkmark badge on profile & posts',
              ),
              const SizedBox(height: 10),

              // Plan 3: Yearly (Save 15%)
              _buildOptionCard(
                id: 'yearly',
                title: 'Verification Only (Yearly)',
                price: 'KES 999/year',
                badgeText: 'SAVE 15%',
                badgeColor: Colors.orange,
                subtitle: '1-Year Verified blue checkmark badge',
              ),
              const SizedBox(height: 28),

              // Pay CTA Button
              GradientButton(
                text: _isUploadingPhoto ? 'UPLOADING TO FIREBASE...' : 'PROCEED TO PAY VIA PAYSTACK',
                onPressed: () async {
                  if (user == null) return;

                  if (_selectedSelfieFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select or capture a verification selfie photo first!')),
                    );
                    return;
                  }

                  setState(() => _isUploadingPhoto = true);

                  // Upload to Firebase Storage: verification/{userId}/photo.jpg
                  final photoUrl = await userProv.uploadVerificationPhoto(
                    userId: user.id,
                    file: _selectedSelfieFile!,
                  );

                  setState(() => _isUploadingPhoto = false);

                  if (photoUrl == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Photo upload failed. Ensure photo is under 2MB.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

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

                  final result = await PaystackService.showPaymentDialog(
                    context: context,
                    title: 'Get Verified on Crushie',
                    description: desc,
                    amountKES: amount,
                    userEmail: user.email,
                  );

                  if (result != null && result.success) {
                    final tx = TransactionModel(
                      id: result.transactionId,
                      userId: user.id,
                      type: type,
                      amount: amount,
                      paymentMethod: result.paymentMethod,
                      paymentReference: result.transactionId,
                      status: 'completed',
                      metadata: {
                        'plan': _selectedOption,
                        'verificationPhoto': photoUrl,
                      },
                    );
                    await FirestoreService().saveTransaction(tx);

                    final updated = user.copyWith(
                      isVerified: true,
                      verifiedExpiry: DateTime.now().add(Duration(days: days)),
                      verificationPhoto: photoUrl,
                      isPremium: type == 'bundle' ? true : user.isPremium,
                      premiumExpiry: type == 'bundle' ? DateTime.now().add(Duration(days: days)) : user.premiumExpiry,
                    );
                    await authProv.updateUserProfile(updated);

                    final notif = NotificationModel(
                      id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
                      userId: user.id,
                      fromUserId: 'system',
                      fromUsername: 'Crushie Support',
                      fromUserProfilePic: '',
                      type: NotificationType.system,
                      title: 'Account Verified!',
                      body: 'Your verification ($desc) has been approved and activated.',
                    );
                    await FirestoreService().createNotification(notif);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎉 Congratulations! Profile Verified & Photo Saved to Firebase!')),
                      );

                      if (widget.onVerifiedSuccess != null) {
                        widget.onVerifiedSuccess!();
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
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
