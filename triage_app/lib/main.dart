import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/auth_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Force portrait + landscape on mobile; unrestricted on desktop
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Dark status-bar icons to contrast against our navy header
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const TriageApp());
}

class TriageApp extends StatelessWidget {
  const TriageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Triage Gateway',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthScreen(),   // ← Entry point is now the auth screen
    );
  }
}
