import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';

class ContactRevealCard extends StatelessWidget {
  final String contactMethod;
  final String contactDetails;
  final String username;

  const ContactRevealCard({
    Key? key,
    required this.contactMethod,
    required this.contactDetails,
    required this.username,
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

  void _launchContact() async {
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
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _badgeColor.withOpacity(0.12),
            AppColors.secondary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _badgeColor.withOpacity(0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lock_open, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'UNLOCKED CONTACT METHOD',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$contactMethod: $contactDetails',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _launchContact,
              icon: Icon(_icon, size: 18, color: Colors.white),
              label: Text(
                'Open in $contactMethod',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                primary: _badgeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
