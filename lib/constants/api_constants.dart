import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String get geminiEndpoint => '$geminiBaseUrl?key=$geminiApiKey';

  static String get cloudflareR2StorageBaseUrl =>
      dotenv.env['CLOUDFLARE_R2_BASE_URL'] ?? '';
}


