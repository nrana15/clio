import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../cards/cards_screen.dart';
import '../upload/upload_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  late final List<Widget> _screens;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys;

  @override
  void initState() {
    super.initState();
    _screens = const [
      DashboardScreen(),
      CardsScreen(),
      UploadScreen(),
      SettingsScreen(),
    ];
    _navigatorKeys = List.generate(
      _screens.length,
      (_) => GlobalKey<NavigatorState>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button - pop from current navigator if possible
        final currentNavigator = _navigatorKeys[_currentIndex];
        if (currentNavigator.currentState?.canPop() ?? false) {
          currentNavigator.currentState?.pop();
          return false;
        }
        // If at root, allow exit if on home tab, otherwise go to home
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens.asMap().entries.map((entry) {
            return Navigator(
              key: _navigatorKeys[entry.key],
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  builder: (context) => entry.value,
                  settings: settings,
                );
              },
            );
          }).toList(),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                // If tapping same tab, pop to root
                if (index == _currentIndex) {
                  _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
                } else {
                  HapticFeedback.lightImpact();
                  setState(() => _currentIndex = index);
                }
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.lightTextSecondary,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 12,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.credit_card_outlined),
                  activeIcon: Icon(Icons.credit_card_rounded),
                  label: 'Cards',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.upload_file_outlined),
                  activeIcon: Icon(Icons.upload_file_rounded),
                  label: 'Upload',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings Screen
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Profile Section
          _ProfileHeader(),
          const Divider(),
          
          // General Settings
          _SettingsSection(
            title: 'General',
            items: [
              _SettingsItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Manage bill reminders',
                onTap: () {
                  // TODO: Navigate to notifications settings
                },
              ),
              _SettingsItem(
                icon: Icons.security_outlined,
                title: 'Security',
                subtitle: 'Biometric & PIN',
                onTap: () {
                  // TODO: Navigate to security settings
                },
              ),
              _SettingsItem(
                icon: Icons.dark_mode_outlined,
                title: 'Appearance',
                subtitle: 'Light & Dark mode',
                onTap: () {
                  // TODO: Navigate to appearance settings
                },
              ),
            ],
          ),
          const Divider(),
          
          // Account Settings
          _SettingsSection(
            title: 'Account',
            items: [
              _SettingsItem(
                icon: Icons.person_outlined,
                title: 'Profile',
                subtitle: 'Manage your profile',
                onTap: () {
                  // TODO: Navigate to profile
                },
              ),
              _SettingsItem(
                icon: Icons.credit_card_outlined,
                title: 'Linked Accounts',
                subtitle: 'Manage connected cards',
                onTap: () {
                  // TODO: Navigate to linked accounts
                },
              ),
            ],
          ),
          const Divider(),
          
          // Support
          _SettingsSection(
            title: 'Support',
            items: [
              _SettingsItem(
                icon: Icons.help_outline,
                title: 'Help Center',
                onTap: () {
                  // TODO: Open help center
                },
              ),
              _SettingsItem(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () {
                  // TODO: Open privacy policy
                },
              ),
              _SettingsItem(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () {
                  // TODO: Open terms
                },
              ),
            ],
          ),
          const Divider(),
          
          // Logout
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutConfirmation(context),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text(
                'Log Out',
                style: TextStyle(color: AppColors.error),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          // Version
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'CLIO v1.0.0',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.lightTextSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Perform logout
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'John Doe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '+1 555 123 4567',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              // TODO: Edit profile
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.lightTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.lightTextSecondary),
      title: Text(title),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.lightTextSecondary,
              ),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
