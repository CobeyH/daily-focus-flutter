/// Example Supabase connection configuration (safe to commit).
///
/// Copy this file to `supabase_config.dart` (git-ignored) and fill in the real
/// values from your Supabase project dashboard:
///
///   * Settings → API → `Project URL`
///   * Settings → API → `publishable` key   (formerly the `anon` key)
///
/// The real `supabase_config.dart` is git-ignored so secrets never end up in
/// version control. See `lib/config/supabase_config.example.dart`.
class SupabaseConfig {
  SupabaseConfig._();

  /// Your Supabase project URL.
  static const String supabaseUrl = 'https://YOUR-PROJECT.supabase.co';

  /// Your Supabase publishable key (formerly the "anon" key).
  static const String supabasePublishableKey = 'YOUR-PUBLISHABLE-KEY';
}
