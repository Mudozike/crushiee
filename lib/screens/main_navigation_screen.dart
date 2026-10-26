import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/post_provider.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/crushie_logo.dart';
import '../widgets/category_sidebar_drawer.dart';
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
import '../services/firestore_service.dart';

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const MainNavigationScreen({
    Key? key,
    required this.onLogout,
  }) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _initializedFollowUserId;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePresence(true);
      _startHeartbeat();
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      _updatePresence(true);
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _updatePresence(true);
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _stopHeartbeat();
      _updatePresence(false);
    }
  }

  void _updatePresence(bool isOnline) {
    try {
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final user = authProv.currentUser;
      if (user != null && user.id.isNotEmpty) {
        FirestoreService().updateUserPresence(user.id, isOnline: isOnline);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _updatePresence(false);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProv = Provider.of<AuthProvider>(context);
    final currentUser = authProv.currentUser;
    if (currentUser != null && _initializedFollowUserId != currentUser.id) {
      _initializedFollowUserId = currentUser.id;
      Provider.of<UserProvider>(context, listen: false)
          .initUserFollowing(currentUser.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final postProv = Provider.of<PostProvider>(context);

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: CategorySidebarDrawer(
        selectedCategory: postProv.selectedCommunity,
        onSelectCategory: (cat) {
          postProv.selectCommunity(cat);
        },
      ),
      appBar: CustomAppBar(
        activeFilterName: postProv.selectedCommunity,
        onTapFilter: () {
          HomeFeedScreen.showFilterBottomSheet(context);
        },
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
              setState(() => _currentIndex = 0);
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
              setState(() => _currentIndex = 0);
            },
          ),
        ],
      ),

      // Prominent Bottom Navigation Bar with Original Crushie Logo for Home
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
          unselectedItemColor: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: [
            // 1. Home Tab with Original Crushie Logo Icon
            BottomNavigationBarItem(
              icon: Opacity(
                opacity: 0.6,
                child: const CrushieLogo(size: 24, showShadow: false),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary,
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const CrushieLogo(size: 26, showShadow: false),
              ),
              label: 'Home',
            ),

            // 2. Discover Tab
            const BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore, color: AppColors.primary),
              label: 'Discover',
            ),

            // 3. Prominent Center Create Post Button
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

            // 4. Messages Tab
            const BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble, color: AppColors.primary),
              label: 'Messages',
            ),

            // 5. Communities Tab
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
