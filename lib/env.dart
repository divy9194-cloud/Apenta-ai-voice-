/// Secrets are injected at build time with --dart-define. Nothing is hard-coded.
class AppEnv {
  static const String geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String chatModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.5-flash');
  static const String imageModel = String.fromEnvironment('GEMINI_IMAGE_MODEL', defaultValue: 'gemini-2.5-flash-image');
  static const String youtubeKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const String countryCode = String.fromEnvironment('DEFAULT_COUNTRY_CODE', defaultValue: '91');
  static const String fbApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String fbAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String fbSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const String fbProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
}
