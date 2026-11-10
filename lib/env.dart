/// All secrets come from --dart-define (never hard-coded). See README.
class Env {
  static const developer = 'Divyanshu Kumar';
  static const geminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const geminiModel = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-2.5-flash');
  static const imageModel = String.fromEnvironment('GEMINI_IMAGE_MODEL', defaultValue: 'gemini-2.5-flash-image');
  static const youtubeKey = String.fromEnvironment('YOUTUBE_API_KEY');
  static const countryCode = String.fromEnvironment('DEFAULT_COUNTRY_CODE', defaultValue: '91');
  static const fbApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const fbAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const fbSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const fbProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
}
