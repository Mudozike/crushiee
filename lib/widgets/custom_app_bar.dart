import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onTapNotifications;
  final VoidCallback onTapSettings;

  const CustomAppBar({
    Key? key,
    required this.onTapNotifications,
    required this.onTapSettings,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProv = Provider.of<AuthProvider>(context);
    final notifProv = Provider.of<NotificationProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context);

    final currentUser = authProv.currentUser;
    final unreadNotifs = currentUser != null ? notifProv.getUnreadCount(currentUser.id) : 0;

    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, size: 24),
            onPressed: onTapNotifications,
          ),
          if (unreadNotifs > 0)
            Positioned(
              top: 10,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unreadNotifs',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
            child: const Text(
              'Crushie',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
      actions: [
        // Theme toggle
        IconButton(
          icon: Icon(
            themeProv.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
            size: 22,
          ),
          onPressed: () => themeProv.toggleTheme(),
        ),
        // Settings gear icon
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 22),
          onPressed: onTapSettings,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
