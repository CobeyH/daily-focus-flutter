# Daily Focus

A Flutter habit and streak tracker for Android and Linux. Task data stays in
SharedPreferences for immediate local access and syncs to Firebase when signed in.

## Task scheduling

Create a task, or choose **Task options → Edit task**. The wizard walks through
Task, Repeat, Visibility, Deadline, Appearance, and Review. Back keeps your draft;
nothing is saved until the final confirmation.

In Repeat, choose **Never repeat** and a due date for a one-off task. It supports
the same visibility and grace settings as recurring tasks. Completion is recorded
once in history and never schedules another occurrence.

Choose **Multi-step** in the Task step for an ordered workflow, such as Wash
laundry → Dry laundry. Add at least two named steps and reorder them with the
arrow controls. Each tap completes the next step; only the final step completes
the task. Undo restores the previous step. Progress syncs with the account and
starts fresh on each scheduled occurrence. Started occurrences keep a snapshot
of their step names, so later definition edits apply to future occurrences.

- **Time slots** (sliders button on the home screen): set Morning, Afternoon, and
  Evening starts. Defaults are 06:00, 12:00, and 18:00, in device local time.
  These app-wide preferences persist on this device. Tasks store a slot reference,
  so changing its start updates every task assigned to it. Existing tasks retain
  their custom appearance times; new tasks default to Morning.
- **Visibility**: choose how many days before due to appear, a slot or custom
  time, and how many days after due to stay visible (or until completed).
  Later slots never hide unfinished earlier tasks. Visibility ends at midnight
  after the final chosen day, independently of streak credit.
- **Tasks / Upcoming tasks**: Today includes actionable tasks and, below them,
  tasks whose visibility will start later today. Other future dates remain in
  the Upcoming view. The list updates at minute boundaries and on app resume.
  Upcoming tasks starts collapsed and shows its count, such as **Upcoming tasks (2)**;
  tap the heading to open or close the list.
- **Complete early today**: tasks appearing later today can be completed directly
  from Upcoming tasks before their slot/custom start. Count progress, multi-step
  actions, and timer starts work early too. The appearance time stays unchanged;
  completion is saved against the same due date, with normal rewards and undo.
  Tasks whose appearance starts on a later calendar day remain unavailable.

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

## Android home-screen widget

Long-press an empty area of the Android home screen, choose **Widgets**, and add
**Daily Focus · Tasks**, or choose **Daily Focus · Tasks (2×2)** for a small square
like a calendar widget. Both versions scroll through the current tasks. The
compact version uses smaller rows and shorter progress labels; it keeps the same
background updates and tap-to-open behavior. Resize either panel to show more rows.
Open the app and sign in once before adding it.

The panel shows current incomplete tasks with progress and due/grace information.
It uses the same recurrence, visibility, and morning/afternoon/evening settings as
the app, includes unfinished tasks from earlier time buckets, and counts tasks
coming later today. Completed and skipped tasks disappear; undo restores them.
Multi-step tasks show the next step. Tap a row/header to open Daily Focus, or use
the refresh button to reload the panel without opening the app. Task completion
and timer controls are handled in the app.

Edits, task progress, synchronization, and time-slot changes update the widget
while the app is running. A short-lived WorkManager job recalculates the panel
from local saved data when the app is closed, using the existing Dart scheduler.
It runs at scheduled visibility/deadline/day boundaries, on manual refresh,
after reboot/time-zone changes, and on Android's periodic widget update.
Android battery restrictions can delay background refreshes. The background job
does not fetch from Firebase or modify tasks. Open the app to pull new changes
from another device. Signing out clears task names from the widget immediately.
Lists over 100 current tasks show a link to the remaining tasks in the app.

Run the Dart tests with `flutter test test/home_widget_test.dart`. With an Android
emulator connected, run native rendering, privacy, and background-refresh tests:

```sh
cd android
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 ./gradlew :app:connectedDebugAndroidTest -Ptarget=lib/main.dart
```

The native test captures light/dark previews to the test device's app cache.
See [light preview](docs/images/task-widget-light.png) and
[dark preview](docs/images/task-widget-dark.png), rendered from the actual Android
RemoteViews with sample task data.
The compact [light](docs/images/task-widget-compact-light.png) and
[dark](docs/images/task-widget-compact-dark.png) previews show the separate 2×2 option.

## Forest rewards

Open the tree button in the app bar to tend your forest. A pine
seedling is provided to start. Each new full task completion earns one seed and
one water, including late completions. Count tasks reward at the goal, timers at
completion, and multi-step tasks after the last step. Partial progress and skips
do not reward resources. Undo and task deletion keep earned rewards; completing
the same task occurrence again never pays twice. Rewards begin with completions
made after this update. Missed days do not change resources or trees.

A newly completed task bursts into small water droplets as it fades and shrinks
out of the list. The droplets gather into the forest button, which pulses on
arrival. Partial progress and skips
do not trigger the effect. Re-completing an undone occurrence replays the burst
without earning additional resources. Device reduced-motion settings disable the effect.

Each rewarded completion also earns 10 lifetime XP. Levels are permanent, with
gradually increasing XP requirements, and expand the clearing. Previous forest
rewards count toward levels automatically. Spending resources does not reduce
XP or lock a variety again.

| Tree | Unlock level | Seed cost |
| --- | --- | --- |
| Pine | 1 | 3 |
| Birch | 2 | 4 |
| Oak | 3 | 5 |
| Maple | 5 | 6 |
| Willow | 8 | 7 |
| Cedar | 12 | 9 |
| Redwood | 16 | 12 |

The forest fills a dedicated screen with a 2.5D isometric clearing, raised earth,
faceted tree canopies, shadows, a pond, and paths. It automatically frames the
whole clearing; there is no draggable map inside a scrolling page. Tap a tree to
select it, use **Closer look at selected tree** for an automatic close-up, and
**View whole forest** to return. The arrow buttons and **Your trees** collection
also select trees without moving around a map.

Water the selected tree from the fixed tending panel. **Plant a tree** opens a
separate nursery; choose a variety there to plant and return to the scene. Tap
the level chip for XP and unlock details. Wide windows put the tending panel
beside the scene, with its own scroll area if needed. It never wraps the scene.
Light/dark themes, reduced motion, and enlarged text are supported.
See the rendered [overview](docs/images/forest-isometric-light.png),
[close-up](docs/images/forest-isometric-close.png), and
[dark scene](docs/images/forest-isometric-dark.png). Interactive phone/wide
landscape previews are in `lib/previews/forest_preview.dart`.

Newly planted trees receive saved positions; existing trees stay in place as the forest grows.
Each tree grows from seedling to young to fully grown with two water actions.
Trees and append-only reward, planting, and watering actions persist locally and
sync to the account's private
`users/{uid}/forest` collection. Stable reward IDs deduplicate across devices.

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

The display name is **Daily Focus** on Android and Linux. Launcher artwork is
maintained in `assets/branding/daily_focus.svg`. To regenerate the committed PNG
sizes and Android foreground/notification vectors, run
`python3 scripts/generate_branding.py` with ImageMagick installed. Android uses
adaptive icons with a themed monochrome variant; Linux bundles the SVG and PNG
under its application ID in the hicolor icon theme.

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
