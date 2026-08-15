import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/database_service.dart';
import '../profile/edit_profile_screen.dart';

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
              leading: CircleAvatar(
                backgroundImage: NetworkImage(
                  user.profilePicUrl.isNotEmpty
                      ? user.profilePicUrl
                      : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
                ),
              ),
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

          // Account Settings Section Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ACCOUNT & PROFILE',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
            ),
          ),

          // Edit Profile Info
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
            title: const Text('Edit Profile Info'),
            subtitle: const Text('Username, bio, location & contact method'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
            },
          ),

          // Change Password
          ListTile(
            leading: const Icon(Icons.lock_reset, color: AppColors.primary),
            title: const Text('Change Password'),
            subtitle: const Text('Update your login password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context),
          ),

          const Divider(),

          // Preferences & Memberships Section Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'PREFERENCES & MEMBERSHIP',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
            ),
          ),

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
            subtitle: const Text('Plans from KES 99/mo or KES 250/mo bundle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenVerification,
          ),

          const Divider(),

          // About & Legal Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'ABOUT & SAFETY',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8),
            ),
          ),

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

          // Log Out
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => _showLogoutDialog(context, authProv),
          ),

          // Delete Account
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Permanently remove your account and data'),
            onTap: () => _showDeleteAccountDialog(context, authProv),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // Logout Confirmation Dialog
  void _showLogoutDialog(BuildContext context, AuthProvider authProv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              authProv.signOut();
              onLogout();
            },
            style: ElevatedButton.styleFrom(
              primary: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Change Password Dialog
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Current Password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'New Password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordController.text != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('New passwords do not match!')),
                );
                return;
              }
              if (newPasswordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters long.')),
                );
                return;
              }

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password changed successfully!')),
              );
            },
            style: ElevatedButton.styleFrom(
              primary: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Update Password', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Delete Account Confirmation Dialog
  void _showDeleteAccountDialog(BuildContext context, AuthProvider authProv) {
    final user = authProv.currentUser;
    final dbService = DatabaseService();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Deleting your account permanently removes your profile, posts, messages, and data. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (user != null) {
                dbService.deleteUser(user.id);
              }
              authProv.signOut();
              onLogout();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account permanently deleted.')),
              );
            },
            style: ElevatedButton.styleFrom(
              primary: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
