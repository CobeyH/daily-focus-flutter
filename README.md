# daily_focus

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Supabase Google sign-in

Google OAuth is handled by Supabase and opens in the system browser. In the
Supabase dashboard, enable the Google provider and add both of these under
**Authentication → URL Configuration → Redirect URLs**:

- `com.dailyfocus.app://login-callback` for Android
- `http://localhost:*/auth/callback` for Linux desktop

The Linux callback binds only to the local machine and uses a temporary port.
Supabase's default PKCE flow verifies the returned authorization code before a
session is created.
