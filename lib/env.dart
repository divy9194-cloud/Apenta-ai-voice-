/// Secrets are injected at build time with --dart-define. Nothing is hard-coded.
class AppEnv {
  static const String claudeKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  static const String claudeModel = String.fromEnvironment('CLAUDE_MODEL', defaultValue: 'claude-sonnet-5-5');
  // low = fastest, medium = quick and smart (default), high = most careful
  static const String claudeEffort = String.fromEnvironment('CLAUDE_EFFORT', defaultValue: 'medium');
  static const String geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String chatModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-flash-latest');
  static const String imageModel = String.fromEnvironment('GEMINI_IMAGE_MODEL', defaultValue: 'gemini-3.1-flash-image');
  static const String metaKey = String.fromEnvironment('META_API_KEY');
  static const String metaImageModel = String.fromEnvironment('META_IMAGE_MODEL', defaultValue: 'muse-image-1.0');
  static const String metaBase = String.fromEnvironment('META_BASE_URL', defaultValue: 'https://api.meta.ai/v1');
  static const String youtubeKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const String countryCode = String.fromEnvironment('DEFAULT_COUNTRY_CODE', defaultValue: '91');
  static const String fbApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String fbAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String fbSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const String fbProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
}
