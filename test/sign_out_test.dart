import 'dart:async';
import 'package:daily_focus/providers/app_controller.dart';
import 'package:daily_focus/screens/auth_screen.dart';
import 'package:daily_focus/screens/home_screen.dart';
import 'package:daily_focus/storage/remote_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SlowClosingRemote implements RemoteStorage {
  bool signedIn = true;
  int watchStarts = 0;
  final cleanup = Completer<void>();
  final auth = StreamController<bool>.broadcast();
  late final watch =
      StreamController<RemoteSnapshot>(onCancel: () => cleanup.future);
  Completer<RemoteSnapshot>? pendingPull;
  @override
  bool get isSignedIn => signedIn;
  @override
  String? get currentUserEmail => 'test@example.test';
  @override
  Stream<bool> observeAuthState() async* {
    yield signedIn;
    yield* auth.stream;
  }

  @override
  Stream<RemoteSnapshot> observeChanges() {
    watchStarts++;
    return watch.stream;
  }

  @override
  Future<RemoteSnapshot> pull() async => pendingPull == null
      ? RemoteSnapshot(tasks: [], entries: [], timers: [])
      : await pendingPull!.future;
  @override
  Future<void> push({required RemoteSnapshot snapshot}) async {}
  @override
  Future<void> signOut() async {
    signedIn = false;
    auth.add(false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
      'account menu signs out immediately even while watch cleanup stalls',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final remote = SlowClosingRemote();
    await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          remoteStorageProvider.overrideWithValue(remote),
        ],
        child: MaterialApp(
            home: Consumer(
                builder: (context, ref, _) =>
                    (ref.watch(authStateProvider).value ?? false)
                        ? const HomeScreen()
                        : const AuthScreen()))));
    await tester.pumpAndSettle();
    expect(remote.watchStarts, 1);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    final coordinator = container.read(syncCoordinatorProvider)!;
    remote.pendingPull = Completer<RemoteSnapshot>();
    final oldSync = coordinator.syncIfSignedIn();
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(remote.isSignedIn, isFalse);
    expect(remote.cleanup.isCompleted, isFalse);
    remote.pendingPull!
        .complete(RemoteSnapshot(tasks: [], entries: [], timers: []));
    await oldSync;
    expect(remote.watchStarts, 1,
        reason: 'An old sync cannot resubscribe after sign-out');
    remote.cleanup.complete();
    await tester.pumpAndSettle();
    addTearDown(() {
      remote.auth.close().ignore();
      remote.watch.close().ignore();
    });
  });
}
