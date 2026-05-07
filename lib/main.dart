import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/disaster_provider.dart';
import 'screens/home_screen.dart';
import 'screens/map_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/preparedness_screen.dart';
import 'screens/alert_history_screen.dart';
import 'screens/city_detail_screen.dart';

import 'services/notification_service.dart';
import 'services/background_service.dart';

/// Global navigator key so we can push routes from notification callbacks.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Notifications & background tasks are mobile-only (dart:io not available on web)
  if (!kIsWeb) {
    final notificationService = NotificationService();
    await notificationService.initialize();
    await notificationService.requestPermissions();

    // Wire up the notification tap handler
    onNotificationTapped = _handleNotificationTap;

    await BackgroundService.initialize();
    await BackgroundService.registerPeriodicTask();
  }

  runApp(const DisasterSenseApp());
}

/// Handle a notification tap — navigate to the relevant city detail screen.
void _handleNotificationTap(String? payload) {
  if (payload == null || payload.isEmpty) return;

  // Payload format: "city:CityName:disasterType"
  final parts = payload.split(':');
  if (parts.length >= 2) {
    final cityName = parts[1];

    // Schedule navigation after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final provider = Provider.of<DisasterProvider>(context, listen: false);
        final data = provider.getCityData(cityName);
        
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => CityDetailScreen(cityName: cityName, data: data),
          ),
        );
      }
    });
  }
}

class DisasterSenseApp extends StatelessWidget {
  const DisasterSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DisasterProvider(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'DisasterSense',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const MainScreen(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFFE64A19), // Deep orange 700 – more vivid seed
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      // Card styling
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2,
        color: isDark ? cs.surfaceContainer : cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isDark
              ? BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))
              : BorderSide.none,
        ),
      ),
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? cs.surface : cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: isDark ? 0 : 2,
        centerTitle: false,
      ),
      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? cs.surfaceContainer : cs.surface,
        indicatorColor: cs.primaryContainer,
        elevation: 0,
      ),
      // Chip / filter chip
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHighest,
        selectedColor: cs.primaryContainer,
        labelStyle: TextStyle(fontSize: 13, color: cs.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: const StadiumBorder(),
      ),
      // Search bar
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHighest),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(
          TextStyle(color: cs.onSurface, fontSize: 15),
        ),
        hintStyle: WidgetStatePropertyAll(
          TextStyle(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 15),
        ),
      ),
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final _screens = const [
    HomeScreen(),
    MapScreen(),
    AlertsScreen(),
    PreparednessScreen(),
    AlertHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Guides',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
