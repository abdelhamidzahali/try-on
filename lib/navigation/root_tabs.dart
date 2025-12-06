import 'package:flutter/material.dart';
import 'package:envisionfit/navigation/app_navigator.dart';
import 'package:envisionfit/screens/tryon_screen.dart';
import 'package:envisionfit/screens/favorites_screen.dart';
import 'package:envisionfit/screens/settings_screen.dart';

class RootTabs extends StatefulWidget {
  const RootTabs({super.key});

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int _index = 0;
  final _navigatorKeys = <GlobalKey<NavigatorState>>[
    GlobalKey<NavigatorState>(), // Try-On tab
    GlobalKey<NavigatorState>(), // Favorites tab
    GlobalKey<NavigatorState>(), // Settings tab
  ];

  @override
  void initState() {
    super.initState();
    AppNavigator.tabIndex.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    AppNavigator.tabIndex.removeListener(_onTabChanged);
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        _index = AppNavigator.tabIndex.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: WillPopScope(
        onWillPop: () async {
          final NavigatorState currentTabNav = _navigatorKeys[_index].currentState!;
          if (currentTabNav.canPop()) {
            currentTabNav.pop();
            return false;
          }
          return true;
        },
        child: IndexedStack(
          index: _index,
          children: [
            _TabNavigator(
              navigatorKey: _navigatorKeys[0],
              builder: (context) => const TryOnScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[1],
              builder: (context) => const FavoritesScreen(showAppBar: false),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[2],
              builder: (context) => const SettingsScreen(showAppBar: false),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xFFE8EDF2)
                    : const Color(0xFF2A3340),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BottomNavigationBar(
                currentIndex: _index,
                onTap: (i) {
                  setState(() => _index = i);
                  AppNavigator.tabIndex.value = i;
                },
                type: BottomNavigationBarType.fixed,
                backgroundColor: colorScheme.surface,
                selectedItemColor: colorScheme.primary,
                unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                showUnselectedLabels: true,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.favorite_border),
                    activeIcon: Icon(Icons.favorite),
                    label: 'Favorites',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabNavigator extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final WidgetBuilder builder;

  const _TabNavigator({
    required this.navigatorKey,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          builder: (context) => builder(context),
          settings: settings,
        );
      },
    );
  }
}
