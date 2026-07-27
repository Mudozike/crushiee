import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import 'feed/home_feed_screen.dart';
import 'discover/discover_screen.dart';
import 'post/create_post_screen.dart';
import 'messages/messages_list_screen.dart';
import 'messages/chat_screen.dart';
import 'communities/communities_screen.dart';
import 'profile/profile_screen.dart';
import 'profile/verification_screen.dart';
import 'premium/premium_subscription_screen.dart';
import 'notifications/notifications_screen.dart';
import 'settings/settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MainNavigationScreen({
    Key? key,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String? _selectedProfileUserId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        onTapNotifications: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          );
        },
        onTapSettings: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                onLogout: widget.onLogout,
                onOpenVerification: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VerificationScreen(
                        onVerifiedSuccess: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
                onOpenPremium: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PremiumSubscriptionScreen(
                        onSubscriptionSuccess: () => Navigator.pop(context),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // Tab 0: Home Feed
          HomeFeedScreen(
            onTapUser: (userId) {
              setState(() => _selectedProfileUserId = userId);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userId: userId,
                    onOpenVerification: () {},
                    onOpenPremium: () {},
                  ),
                ),
              );
            },
          ),

          // Tab 1: Discover
          DiscoverScreen(
            onTapUser: (userId) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userId: userId,
                  ),
                ),
              );
            },
          ),

          // Tab 2: Create Post
          CreatePostScreen(
            onPostCreated: () {
              setState(() => _currentIndex = 0); // Switch to feed after post
            },
          ),

          // Tab 3: Messages & Connections
          MessagesListScreen(
            onSelectConnection: (connection) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(connection: connection),
                ),
              );
            },
          ),

          // Tab 4: Communities
          CommunitiesScreen(
            onSelectCommunity: () {
              setState(() => _currentIndex = 0); // Switch to home feed for filtered community
            },
          ),
        ],
      ),

      // Prominent Bottom Navigation Bar (5 tabs)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home, color: AppColors.primary),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore, color: AppColors.primary),
              label: 'Discover',
            ),
            // Prominent Center Create Post Button
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
              label: 'Post',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble, color: AppColors.primary),
              label: 'Messages',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view, color: AppColors.primary),
              label: 'Communities',
            ),
          ],
        ),
      ),
    );
  }
}
