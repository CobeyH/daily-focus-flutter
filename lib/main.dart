import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_controller.dart';
import 'providers/clock_provider.dart';
import 'providers/timer_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'storage/firebase_storage.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  FirebaseStorage? remote;
  String? initializationError;
  try {
    remote = await FirebaseStorage.open();
  } catch (e) {
    initializationError = 'Could not open secure sign-in storage. $e';
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        remoteStorageProvider.overrideWith((ref) {
          ref.onDispose(() => remote?.dispose());
          return remote;
        }),
        cloudInitializationErrorProvider.overrideWithValue(initializationError),
      ],
      child: const DailyFocusApp(),
    ),
  );
}

class DailyFocusApp extends ConsumerStatefulWidget {
  const DailyFocusApp({super.key});

  @override
  ConsumerState<DailyFocusApp> createState() => _DailyFocusAppState();
}

class _DailyFocusAppState extends ConsumerState<DailyFocusApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize the notification service (also requests permission).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(clockProvider);
      ref.read(timerControllerProvider.notifier).checkForElapsed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Focus',
      debugShowCheckedModeBanner: false,
      theme: focusTheme(Brightness.light),
      darkTheme: focusTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const _AuthGate(),
    );
  }
}

/// Shows the sign-in screen until a user is authenticated, then the home
/// screen. Tests can use a null remote backend for local-only mode.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(cloudInitializationErrorProvider);
    if (error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(error),
                TextButton(onPressed: main, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    final auth = ref.watch(authStateProvider);
    final signedIn = auth.value ?? false;
    return signedIn ? const HomeScreen() : const AuthScreen();
  }
}
