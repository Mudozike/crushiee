import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/crushie_avatar.dart';
import '../profile/edit_profile_screen.dart';
import '../admin/admin_revenue_dashboard_screen.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onOpenVerification;
  final VoidCallback onOpenPremium;

  const SettingsScreen({
    super.key,
    required this.onLogout,
    required this.onOpenVerification,
    required this.onOpenPremium,
  });

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
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        children: [
          if (user != null) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: user.profilePicUrl.startsWith('crushie_avatar_')
                    ? CrushieAvatar(
                        index: int.tryParse(user.profilePicUrl
                                .replaceAll('crushie_avatar_', '')) ??
                            0,
                        radius: 22,
                      )
                    : user.profilePicUrl.startsWith('http')
                        ? CircleAvatar(
                            backgroundImage:
                                CachedNetworkImageProvider(user.profilePicUrl),
                          )
                        : CircleAvatar(
                            backgroundImage: user.profilePicUrl.isNotEmpty
                                ? FileImage(File(user.profilePicUrl))
                                    as ImageProvider
                                : const NetworkImage(
                                    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400'),
                          ),
                title: Text('@${user.username}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user.email, overflow: TextOverflow.ellipsis),
                trailing: user.isVerified
                    ? const Icon(Icons.verified, color: AppColors.verifiedBlue)
                    : OutlinedButton(
                        onPressed: onOpenVerification,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Verify',
                            style: TextStyle(fontSize: 12)),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Account Settings Section Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'ACCOUNT & PROFILE',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.8),
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
            onTap: () => _showChangePasswordDialog(context, authProv),
          ),

          const SizedBox(height: 16),

          // Preferences & Memberships Section Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'PREFERENCES & MEMBERSHIP',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.8),
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
            leading:
                const Icon(Icons.verified_user, color: AppColors.verifiedBlue),
            title: const Text('Verify Profile Badge'),
            subtitle: const Text('Plans from KES 99/mo or KES 250/mo bundle'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onOpenVerification,
          ),

          // Admin Revenue Dashboard
          ListTile(
            leading:
                const Icon(Icons.admin_panel_settings, color: Colors.purple),
            title: const Text('Admin Revenue Dashboard'),
            subtitle: const Text('View live revenue, transactions & analytics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminRevenueDashboardScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          // Notifications & Preferences Section Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'NOTIFICATIONS & ALERTS',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.8),
            ),
          ),

          if (user != null)
            SwitchListTile(
              secondary: const Icon(Icons.location_on_outlined,
                  color: Colors.deepOrange),
              title: const Text('Juja Local Post Alerts'),
              subtitle: const Text(
                  'Receive opt-in notifications for new posts in Juja'),
              value: user.locationNotificationSubscriptions.contains('Juja'),
              activeColor: AppColors.primary,
              onChanged: (enabled) async {
                final currentList =
                    List<String>.from(user.locationNotificationSubscriptions);
                if (enabled) {
                  if (!currentList.contains('Juja')) currentList.add('Juja');
                } else {
                  currentList.remove('Juja');
                }
                final updated = user.copyWith(
                    locationNotificationSubscriptions: currentList);
                await authProv.updateUserProfile(updated);
              },
            ),

          const SizedBox(height: 16),

          // About & Legal Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              'ABOUT & SAFETY',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.8),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About Crushie'),
            subtitle: const Text(
                'v1.0.0 • Meet people who want the same thing you do'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service & Privacy Policy'),
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Log Out
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log Out',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => _showLogoutDialog(context, authProv),
          ),

          // Delete Account
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
    bool isLoggingOut = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Out'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: isLoggingOut ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoggingOut
                  ? null
                  : () async {
                      setDialogState(() => isLoggingOut = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final success = await authProv.signOut();
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);

                      if (success) {
                        onLogout();
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(authProv.errorMessage ??
                                'Sign out failed. Please try again.'),
                            backgroundColor: Colors.red.shade700,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: isLoggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Log Out',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // Change Password Dialog
  void _showChangePasswordDialog(BuildContext context, AuthProvider authProv) {
    if (authProv.isGoogleUser) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.g_mobiledata, color: AppColors.primary, size: 28),
              SizedBox(width: 8),
              Text('Google Account'),
            ],
          ),
          content: const Text(
            'Your account is signed in via Google. Password management is handled securely through your Google Account settings.',
            style: TextStyle(height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('OK',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (currentPasswordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please enter your current password.')),
                          );
                          return;
                        }
                        if (newPasswordController.text !=
                            confirmPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('New passwords do not match!')),
                          );
                          return;
                        }
                        if (newPasswordController.text.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Password must be at least 6 characters long.')),
                          );
                          return;
                        }

                        setModalState(() => isLoading = true);
                        final success = await authProv.changePassword(
                          currentPassword: currentPasswordController.text,
                          newPassword: newPasswordController.text,
                        );
                        setModalState(() => isLoading = false);

                        if (context.mounted) {
                          if (success) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password changed successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(authProv.errorMessage ??
                                    'Failed to change password.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Password',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Delete Account Confirmation Dialog
  void _showDeleteAccountDialog(BuildContext context, AuthProvider authProv) {
    final user = authProv.currentUser;
    final effectiveUid = user?.id ?? authProv.firebaseUser?.uid;
    final passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: const [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Flexible(child: Text('Delete Account?')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Deleting your account permanently removes your profile, posts, messages, and data. This cannot be undone.',
                  style: TextStyle(height: 1.4),
                ),
                if (!authProv.isGoogleUser) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password to Delete',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        if (effectiveUid == null || effectiveUid.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('No active user session to delete.')),
                          );
                          return;
                        }

                        if (!authProv.isGoogleUser &&
                            passwordController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please enter your password to confirm deletion.')),
                          );
                          return;
                        }

                        setModalState(() => isLoading = true);
                        final success = await authProv.deleteAccount(
                          effectiveUid,
                          currentPassword: passwordController.text,
                        );
                        setModalState(() => isLoading = false);

                        if (context.mounted) {
                          if (success) {
                            Navigator.pop(ctx);
                            onLogout();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account permanently deleted.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(authProv.errorMessage ??
                                    'Failed to delete account.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Delete Account',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}
