import 'package:flutter/material.dart';
import 'package:envisionfit/theme.dart';
import 'package:envisionfit/navigation/root_tabs.dart';
import 'package:envisionfit/navigation/app_navigator.dart';
import 'package:envisionfit/supabase/supabase_config.dart';
import 'package:envisionfit/screens/onboarding_welcome_screen.dart';
import 'package:envisionfit/screens/gender_selection_screen.dart';
import 'package:envisionfit/screens/onboarding_photos_screen.dart';
import 'package:envisionfit/screens/onboarding_fullbody_screen.dart';
import 'package:envisionfit/screens/settings_screen.dart';
import 'package:envisionfit/screens/tryon_screen.dart';
import 'package:envisionfit/services/onboarding_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Global error handlers to surface silent failures in the web preview
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };
  WidgetsBinding.instance.platformDispatcher.onError = (Object error, StackTrace stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrint(stack.toString());
    return true; // prevent default crash behavior
  };
  debugPrint('[main] Initializing Supabase...');
  await SupabaseConfig.initialize();
  debugPrint('[main] Supabase initialized. Running app...');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('[MyApp] build');
    return MaterialApp(
      title: 'EnvisionFit - AI Virtual Try-On',
      debugShowCheckedModeBanner: false,
      navigatorKey: AppNavigator.navigatorKey,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: const _AppStartGate(),
    );
  }
}

class _AppStartGate extends StatefulWidget {
  const _AppStartGate();

  @override
  State<_AppStartGate> createState() => _AppStartGateState();
}

class _AppStartGateState extends State<_AppStartGate> {
  late Future<bool> _future;
  // Toggle this to true to force-show onboarding in preview
  static const bool _previewOnboarding = true;

  @override
  void initState() {
    super.initState();
    debugPrint('[_AppStartGate] initState');
    _future = OnboardingService.isCompleted();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[_AppStartGate] build; previewOnboarding=$_previewOnboarding');
    if (_previewOnboarding) {
      // In preview, start directly on the Google Sign-In / Welcome screen
      debugPrint('[_AppStartGate] Showing OnboardingWelcomeScreen (preview start)');
      return const OnboardingWelcomeScreen();
    }
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final done = snapshot.data ?? false;
        return done ? const RootTabs() : const OnboardingWelcomeScreen();
      },
    );
  }
}
