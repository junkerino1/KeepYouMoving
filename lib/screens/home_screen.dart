import 'package:flutter/material.dart';
import '../controllers/theme_controller.dart';
import 'live_map_screen.dart';
import 'profile_screen.dart';
import 'routes_screen.dart';
import 'timetable_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.themeController});

  /// App-wide theme mode, shared with `RapidTransitApp` and the Profile
  /// screen's theme picker.
  final ThemeController themeController;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  /// External query pushed into the Routes tab (e.g. from the global search
  /// on the map). RoutesScreen listens and reuses its existing filter logic.
  final ValueNotifier<String> _routesQuery = ValueNotifier('');

  late final List<Widget> _screens = [
    LiveMapScreen(onOpenRouteSearch: _openRoutesWithQuery),
    RoutesScreen(externalQuery: _routesQuery),
    const TimetableScreen(),
    ProfileScreen(themeController: widget.themeController),
  ];

  /// Switches to the Routes tab and seeds its search with [query].
  void _openRoutesWithQuery(String query) {
    _routesQuery.value = query;
    setState(() => _currentIndex = 1);
  }

  @override
  void dispose() {
    _routesQuery.dispose();
    super.dispose();
  }

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.map_outlined),
      selectedIcon: Icon(Icons.map_rounded),
      label: 'Map',
    ),
    NavigationDestination(
      icon: Icon(Icons.departure_board_outlined),
      selectedIcon: Icon(Icons.departure_board_rounded),
      label: 'Routes',
    ),
    NavigationDestination(
      icon: Icon(Icons.schedule_outlined),
      selectedIcon: Icon(Icons.schedule_rounded),
      label: 'Timetable',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Material "expanded" breakpoint: switch the phone bottom bar to a
        // navigation rail on tablets, desktops and wide windows instead of
        // stretching the phone layout.
        final isExpanded = constraints.maxWidth >= 600;

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: isExpanded
                      ? Row(
                          children: [
                            NavigationRail(
                              selectedIndex: _currentIndex,
                              onDestinationSelected: (index) =>
                                  setState(() => _currentIndex = index),
                              labelType: NavigationRailLabelType.all,
                              destinations: [
                                for (final destination in _destinations)
                                  NavigationRailDestination(
                                    icon: destination.icon,
                                    selectedIcon: destination.selectedIcon,
                                    label: Text(destination.label),
                                  ),
                              ],
                            ),
                            VerticalDivider(
                              width: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                            Expanded(
                              child: IndexedStack(
                                index: _currentIndex,
                                children: _screens,
                              ),
                            ),
                          ],
                        )
                      : IndexedStack(
                          index: _currentIndex,
                          children: _screens,
                        ),
                ),
                if (!isExpanded)
                  NavigationBar(
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) =>
                        setState(() => _currentIndex = index),
                    destinations: _destinations,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
