import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onTapNotifications;
  final VoidCallback onTapSettings;
  final VoidCallback? onTapFilter;
  final String activeFilterName;

  const CustomAppBar({
    Key? key,
    required this.onTapNotifications,
    required this.onTapSettings,
    this.onTapFilter,
    this.activeFilterName = 'All',
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
    final isFiltered = activeFilterName != 'All';

    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Crushie Brand Title
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
          
          // Active Filter Badge if selected
          if (isFiltered) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child: Text(
                activeFilterName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        // 4. Subtle FILTER Icon/Button beside controls
        if (onTapFilter != null)
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.tune_rounded,
                  color: isFiltered ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                  size: 22,
                ),
                onPressed: onTapFilter,
                tooltip: 'Filter Categories',
              ),
              if (isFiltered)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),

        // Notifications Icon
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 22),
              onPressed: onTapNotifications,
            ),
            if (unreadNotifs > 0)
              Positioned(
                top: 10,
                right: 10,
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
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Theme toggle
        IconButton(
          icon: Icon(
            themeProv.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
            size: 20,
          ),
          onPressed: () => themeProv.toggleTheme(),
        ),

        // Settings gear icon
        IconButton(
          icon: const Icon(Icons.settings_outlined, size: 20),
          onPressed: onTapSettings,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
