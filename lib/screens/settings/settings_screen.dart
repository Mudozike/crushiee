import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onOpenVerification;
  final VoidCallback onOpenPremium;

  const SettingsScreen({
    Key? key,
    required this.onLogout,
    required this.onOpenVerification,
    required this.onOpenPremium,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);
    final user = authProv.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Privacy'),
      ),
      body: ListView(
        children: [
          if (user != null) ...[
            ListTile(
              leading: const CircleAvatar(backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400')),
              title: Text('@${user.username}', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(user.email),
              trailing: user.isVerified
                  ? const Icon(Icons.verified, color: AppColors.verifiedBlue)
                  : OutlinedButton(
                      onPressed: onOpenVerification,
                      child: const Text('Verify'),
                    ),
            ),
            const Divider(),
          ],

          // Theme Switcher
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable sleek dark theme'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: themeProv.isDarkMode,
            onChanged: (val) => themeProv.toggleTheme(),
          ),

          // Upgrade to Premium
          ListTile(
            leading: const Icon(Icons.star, color: Colors.amber),
            title: const Text('Crushie Premium Subscription'),
            subtitle: const Text('Unlimited connections for KES 200/mo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenPremium,
          ),

          // Verification
          ListTile(
            leading: const Icon(Icons.verified_user, color: AppColors.verifiedBlue),
            title: const Text('Verify Profile Badge'),
            subtitle: const Text('Lifetime KES 499 selfie verification'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenVerification,
          ),

          const Divider(),

          // About & Legal
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Crushie'),
            subtitle: const Text('v1.0.0 • Meet people who want the same thing you do'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service & Privacy Policy'),
            onTap: () {},
          ),

          const Divider(),

          // Log Out Button
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
              authProv.signOut();
              onLogout();
            },
          ),
        ],
      ),
    );
  }
}
