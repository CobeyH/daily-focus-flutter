# Daily Focus

A Flutter habit and streak tracker for Android and Linux. Task data stays in
SharedPreferences for immediate local access and syncs to Firebase when signed in.

## Task scheduling

Create a task, or choose **Task options → Edit task**. The wizard walks through
Task, Repeat, Timing, Appearance, and Review. Back keeps your draft; nothing is
saved until the final confirmation. Appearance and grace settings are on Timing:

- **Show in Today**: the due day or up to 30 days earlier, with an appearance time.
- **Due time**: a specific local time, or end of day.
- **Grace period**: none (strict), or up to 30 calendar days late. A Wednesday
  task with two grace days can be completed through Friday at the same due time.

Today shows available tasks and collapses completed/skipped occurrences. Upcoming
shows the next unopened occurrence for each task; All includes off-day tasks.
History distinguishes on-time, within-grace, late, missed, skipped, and rest days.

Progress belongs to one scheduled due date. Early/late completions store their
actual completion time; undo targets that same occurrence, including after sync.
Completion within grace preserves the streak. Beyond grace it is recorded as
late and does not repair the streak. Explicit skips preserve it without adding.

If grace windows overlap, the older unfinished occurrence is offered first.
Once a new cycle is due, an expired older cycle stays in history rather than
building an unlimited backlog. Until then, an unfinished recurring task remains
visible. Fixed schedules never slide with completion. Monthly tasks on the 29th,
30th, or 31st use the last day of shorter months. All times follow device local
time; grace periods and recurrence use calendar arithmetic across DST.

Existing tasks default to no grace and same-day visibility. Existing completion
history is retained without inventing timestamps. Editing timing does not restart
a running timer. Deadline reminders are not added; timer alerts retain their
existing platform support.

## Firebase backend

The project is `daily-focus-cobey`, on Firebase's free Spark plan. Authentication
uses email/password and Google; Cloud Firestore Standard stores each user's data
in `users/{uid}/tasks`, `entries`, and `active_timers`. The database is in `us-west1`.
Firestore rules limit reads and writes to the matching Firebase Auth user.

Firebase's Flutter plugins do not support Linux. This app uses the pure Dart
`firedart` client on both platforms, so desktop login and live synchronization
remain available. Sessions are stored using `flutter_secure_storage` (Linux
Secret Service or Android encrypted storage), separate from local task data.

On Android, Google sign-in uses the native Google account picker via
`google_sign_in`. The Firebase Android app is registered as
`com.dailyfocus.daily_focus`, with this workstation's debug signing SHA-1.
The public web OAuth client ID is passed as `serverClientId` from
`FirebaseConfig`; no Google Services Gradle plugin is needed. Other signing keys
(including Play App Signing) must have their SHA-1 registered in Firebase before
those builds can use Google sign-in. Canceling the picker leaves the login screen.

On Linux, Google sign-in opens `https://daily-focus-cobey.firebaseapp.com/sign-in/` in the
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
TZ=America/Vancouver flutter test
node --test test/google_callback.test.mjs
firebase emulators:exec --project demo-daily-focus --only auth,firestore \
  'TZ=America/Vancouver flutter test --dart-define=FIREBASE_EMULATOR_TEST=true'
```

The integration tests cover email and Google credential sign-in, live sync,
idempotent updates, deletion of related records, and rejection of unauthenticated
and other-account access. They use local emulators and no real user data.
