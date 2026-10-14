/// 빌드할 때 --dart-define 으로 넣는 값. 키를 코드에 적지 않는다.
///
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_PUBLISHABLE_KEY=... \
///   --dart-define=GOOGLE_WEB_CLIENT_ID=....apps.googleusercontent.com
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty && googleWebClientId.isNotEmpty;
}
