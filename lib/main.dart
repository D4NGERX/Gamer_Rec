// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/di/injection.dart';
import 'core/theme/app_theme.dart';
import 'features/recording/presentation/pages/recording_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('dark_mode') ?? true;

  // Lock to portrait — settings and recording management are portrait-first
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Immersive edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkMode ? Brightness.light : Brightness.dark,
      systemNavigationBarColor: isDarkMode ? const Color(0xFF0D0D0D) : Colors.white,
    ),
  );

  configureDependencies();
  runApp(GamerRecApp(initialBrightness: isDarkMode ? Brightness.dark : Brightness.light));
}

class GamerRecApp extends StatefulWidget {
  final Brightness initialBrightness;

  const GamerRecApp({super.key, required this.initialBrightness});

  @override
  State<GamerRecApp> createState() => _GamerRecAppState();
}

class _GamerRecAppState extends State<GamerRecApp> {
  late Brightness _currentBrightness;

  @override
  void initState() {
    super.initState();
    _currentBrightness = widget.initialBrightness;
  }

  void toggleTheme() async {
    final newBrightness = _currentBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', newBrightness == Brightness.dark);

    setState(() {
      _currentBrightness = newBrightness;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ThemeToggleProvider(
      brightness: _currentBrightness,
      toggleTheme: toggleTheme,
      child: MaterialApp(
        title: 'Gamer Rec',
        theme: createAppTheme(_currentBrightness),
        debugShowCheckedModeBanner: false,
        home: const RecordingPage(),
      ),
    );
  }
}

/// Provider for theme toggle across the app
class ThemeToggleProvider extends InheritedWidget {
  final Brightness brightness;
  final VoidCallback toggleTheme;

  const ThemeToggleProvider({
    super.key,
    required this.brightness,
    required this.toggleTheme,
    required super.child,
  });

  static ThemeToggleProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<ThemeToggleProvider>();
    assert(provider != null, 'ThemeToggleProvider not found in widget tree');
    return provider!;
  }

  @override
  bool updateShouldNotify(ThemeToggleProvider oldWidget) {
    return brightness != oldWidget.brightness;
  }
}
