import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/app_controller.dart';
import 'providers/timer_controller.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase for cross-device sync. If the placeholders are still
  // present (a project hasn't been configured yet), fall back to local-only
  // mode so development isn't blocked.
  bool supabaseReady = false;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      publishableKey: SupabaseConfig.supabasePublishableKey,
    );
    supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase init skipped (local-only mode): $e');
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supabaseAvailableProvider.overrideWithValue(supabaseReady),
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
      ref.read(timerControllerProvider.notifier).checkForElapsed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Focus',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF5C6BC0),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Shows the sign-in screen until a user is authenticated, then the home
/// screen. In local-only mode (no Supabase) it always shows home.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final signedIn = auth.value ?? false;
    return signedIn ? const HomeScreen() : const AuthScreen();
  }
}
