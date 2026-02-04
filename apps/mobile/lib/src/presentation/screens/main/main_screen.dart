import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../dashboard/dashboard_screen.dart';
import '../cards/cards_screen.dart';
import '../upload/upload_screen.dart';
import '../settings/settings_screen.dart';

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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        // Handle back button - pop from current navigator if possible
        final currentNavigator = _navigatorKeys[_currentIndex];
        if (currentNavigator.currentState?.canPop() ?? false) {
          currentNavigator.currentState?.pop();
          return;
        }
        // If at root, go to home tab
        if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
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
