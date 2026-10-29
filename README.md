# Daily Focus

A Flutter habit and streak tracker for Android and Linux. Task data stays in
SharedPreferences for immediate local access and syncs to Firebase when signed in.

## Firebase backend

The project is `daily-focus-cobey`, on Firebase's free Spark plan. Authentication
uses email/password and Google; Cloud Firestore Standard stores each user's data
in `users/{uid}/tasks`, `entries`, and `active_timers`. The database is in `us-west1`.
Firestore rules limit reads and writes to the matching Firebase Auth user.

Firebase's Flutter plugins do not support Linux. This app uses the pure Dart
`firedart` client on both platforms, so desktop login and live synchronization
remain available. Sessions are stored using `flutter_secure_storage` (Linux
Secret Service or Android encrypted storage), separate from local task data.

Google sign-in opens `https://daily-focus-cobey.firebaseapp.com/sign-in/` in the
system browser. That page uses Firebase's official JavaScript SDK and returns a
short-lived Google credential to a listener bound only to `127.0.0.1` on a random
port. The callback checks the request origin and a random state; the hosted page
accepts only loopback callback addresses. The app exchanges the Google credential
for its own Firebase session. After login, return to the app; no custom URL scheme
or Linux URL-handler installation is needed. Closing the browser cancels the flow
after five minutes.

Public client identifiers are in `lib/config/firebase_config.dart`. No service
account credentials or OAuth client secret belong in the app. Backend changes:

```sh
firebase deploy --only firestore:rules,firestore:indexes,hosting
```

Enable Email/Password and Google in Firebase Console → Authentication → Sign-in
method. Existing Supabase accounts and cloud data are not imported. Local tasks,
history and timers retain their existing storage format and are uploaded after
the first Firebase sign-in. The old Supabase schema in `docs/` is historical and
is no longer used by the app.

## Development

```sh
flutter pub get
flutter run -d linux
```

Linux builds require `libsecret-1-dev` and `libjsoncpp-dev` and a running Secret
Service keyring. Android uses the Flutter project's existing SDK configuration.

## Verification

```sh
flutter analyze
flutter test
node --test test/google_callback.test.mjs
firebase emulators:exec --project demo-daily-focus --only auth,firestore \
  'flutter test test/firebase_storage_integration_test.dart --dart-define=FIREBASE_EMULATOR_TEST=true'
```

The integration tests cover email and Google credential sign-in, live sync,
idempotent updates, deletion of related records, and rejection of unauthenticated
and other-account access. They use local emulators and no real user data.
