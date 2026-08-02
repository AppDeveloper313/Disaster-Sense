import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
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
    
    // Deep obsidian and sleek greys for dark mode, clean white/grey for light mode
    final cs = ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF5722), // Vibrant Deep Orange
      brightness: brightness,
      surface: isDark ? const Color(0xFF0F1014) : const Color(0xFFF8F9FA),
      surfaceContainer: isDark ? const Color(0xFF16181D) : const Color(0xFFFFFFFF),
      surfaceContainerHighest: isDark ? const Color(0xFF1E2028) : const Color(0xFFF0F2F5),
      primary: const Color(0xFFFF5722),
      secondary: const Color(0xFF00E5FF), // Cyan accent
      tertiary: const Color(0xFFFF2A5F), // Pink/Red accent
    );

    final baseTextTheme = brightness == Brightness.dark 
        ? ThemeData.dark().textTheme 
        : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: GoogleFonts.outfitTextTheme(baseTextTheme),
      
      // Card styling for glassmorphism aesthetic
      cardTheme: CardThemeData(
        elevation: 0,
        color: cs.surfaceContainer.withValues(alpha: 0.7),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: isDark ? 0.2 : 0.5),
            width: 1,
          ),
        ),
      ),
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      
      // Navigation bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: cs.primary.withValues(alpha: 0.2),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            );
          }
          return GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: cs.onSurfaceVariant,
          );
        }),
      ),
      
      // Chip / filter chip
      chipTheme: ChipThemeData(
        backgroundColor: cs.surfaceContainerHighest,
        selectedColor: cs.primary,
        labelStyle: GoogleFonts.outfit(fontSize: 13, color: cs.onSurface),
        secondaryLabelStyle: GoogleFonts.outfit(fontSize: 13, color: cs.onPrimary, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        side: BorderSide.none,
      ),
      
      // Search bar
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHighest.withValues(alpha: 0.7)),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        textStyle: WidgetStatePropertyAll(
          GoogleFonts.outfit(color: cs.onSurface, fontSize: 15),
        ),
        hintStyle: WidgetStatePropertyAll(
          GoogleFonts.outfit(color: cs.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 15),
        ),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Scaffold(
      extendBody: true, // Allows body to go behind the bottom nav bar
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                height: 65,
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
            ),
          ),
        ),
      ),
    );
  }
}
