import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class ContactRevealCard extends StatelessWidget {
  final String contactMethod;
  final String contactDetails;
  final String username;
  final bool isBlocked;
  final bool isPaid;
  final bool isAuthorized;

  const ContactRevealCard({
    Key? key,
    required this.contactMethod,
    required this.contactDetails,
    required this.username,
    this.isBlocked = false,
    this.isPaid = false,
    this.isAuthorized = false,
  }) : super(key: key);

  /// Helper to check whether contact information is present and valid.
  static bool isValidContact(String? method, String? details) {
    if (method == null || details == null) return false;
    final m = method.trim().toLowerCase();
    final d = details.trim();
    if (m.isEmpty || d.isEmpty) return false;
    if (m == 'whatsapp' || m == 'phone call' || m == 'phone') {
      final digits = d.replaceAll(RegExp(r'[^0-9]'), '');
      return digits.length >= 8 && digits.length <= 15;
    }
    if (m == 'email') {
      return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(d);
    }
    if (m == 'telegram') {
      final handle = d.replaceAll('@', '').trim();
      return handle.length >= 3;
    }
    return false;
  }

  /// Normalizes phone numbers, stripping out non-digit characters.
  static String? normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8 || digits.length > 15) return null;
    return digits;
  }

  IconData get _icon {
    switch (contactMethod.toLowerCase()) {
      case 'whatsapp':
        return Icons.chat;
      case 'telegram':
        return Icons.send;
      case 'phone call':
      case 'phone':
        return Icons.phone;
      case 'email':
        return Icons.email;
      default:
        return Icons.contact_phone;
    }
  }

  Color get _badgeColor {
    switch (contactMethod.toLowerCase()) {
      case 'whatsapp':
        return Colors.green;
      case 'telegram':
        return Colors.lightBlue;
      case 'phone call':
      case 'phone':
        return Colors.orange;
      case 'email':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  void _showRestrictedContactNotice(BuildContext context) {
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unblock @$username to view contact actions.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Direct contact opening is temporarily unavailable pending server verification. Please use secure in-app messaging.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isValidContact(contactMethod, contactDetails)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasAccess = (isPaid || isAuthorized) && !isBlocked;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked
              ? Colors.grey.withOpacity(0.3)
              : (hasAccess
                  ? _badgeColor.withOpacity(0.3)
                  : Colors.amber.withOpacity(0.3)),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isBlocked
                      ? Colors.grey
                      : (hasAccess ? _badgeColor : Colors.amber.shade700),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isBlocked
                              ? Icons.block
                              : (hasAccess ? Icons.lock_open : Icons.lock),
                          size: 13,
                          color: isBlocked
                              ? Colors.grey
                              : (hasAccess
                                  ? Colors.green
                                  : Colors.amber.shade800),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            isBlocked
                                ? 'CONTACT BLOCKED'
                                : (hasAccess
                                    ? 'UNLOCKED CONTACT METHOD'
                                    : 'PRIVATE CONTACT LOCKED'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isBlocked
                                  ? Colors.grey
                                  : (hasAccess
                                      ? Colors.green.shade700
                                      : Colors.amber.shade800),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBlocked
                          ? 'Contact unavailable while blocked'
                          : (hasAccess
                              ? '$contactMethod: $contactDetails'
                              : '$contactMethod: Private Contact Locked'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isBlocked
                            ? Colors.grey
                            : (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!isBlocked) ...[
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () => _showRestrictedContactNotice(context),
                icon: const Icon(Icons.lock_outline,
                    size: 16, color: Colors.white),
                label: const Text(
                  'Contact Opening Unavailable',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade600,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Direct external messaging is temporarily disabled pending server verification. Please chat in-app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Contact action disabled while user is blocked',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
