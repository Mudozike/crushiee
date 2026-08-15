import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';

class ContactRevealCard extends StatelessWidget {
  final String contactMethod;
  final String contactDetails;
  final String username;
  final bool isBlocked;

  const ContactRevealCard({
    Key? key,
    required this.contactMethod,
    required this.contactDetails,
    required this.username,
    this.isBlocked = false,
  }) : super(key: key);

  IconData get _icon {
    switch (contactMethod.toLowerCase()) {
      case 'whatsapp':
        return Icons.chat;
      case 'telegram':
        return Icons.send;
      case 'phone call':
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
        return Colors.orange;
      case 'email':
        return Colors.purple;
      default:
        return AppColors.primary;
    }
  }

  void _launchContact(BuildContext context) async {
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Unblock @$username to open $contactMethod.")),
      );
      return;
    }

    Uri uri;
    switch (contactMethod.toLowerCase()) {
      case 'whatsapp':
        final cleanPhone = contactDetails.replaceAll(RegExp(r'[^0-9+]'), '');
        uri = Uri.parse('https://wa.me/$cleanPhone');
        break;
      case 'telegram':
        final cleanHandle = contactDetails.replaceAll('@', '');
        uri = Uri.parse('https://t.me/$cleanHandle');
        break;
      case 'phone call':
        uri = Uri.parse('tel:$contactDetails');
        break;
      case 'email':
        uri = Uri.parse('mailto:$contactDetails');
        break;
      default:
        uri = Uri.parse('tel:$contactDetails');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBlocked ? Colors.grey.withOpacity(0.3) : _badgeColor.withOpacity(0.3),
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
                  color: isBlocked ? Colors.grey : _badgeColor,
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
                          isBlocked ? Icons.lock : Icons.lock_open,
                          size: 13,
                          color: isBlocked ? Colors.grey : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'UNLOCKED CONTACT METHOD',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isBlocked ? Colors.grey : Colors.green.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$contactMethod: $contactDetails',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isBlocked
                            ? Colors.grey
                            : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isBlocked) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () => _launchContact(context),
                icon: Icon(_icon, size: 16, color: Colors.white),
                label: Text(
                  'Open in $contactMethod',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  primary: _badgeColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Contact action disabled while user is blocked',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
