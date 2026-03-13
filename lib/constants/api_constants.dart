import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static String get geminiEndpoint => '$geminiBaseUrl?key=$geminiApiKey';

  static String get cloudflareR2StorageBaseUrl =>
      dotenv.env['CLOUDFLARE_R2_BASE_URL'] ?? '';

  // Motion Storage Configuration
  // Set to 'local' to use local files, 'r2' to use Cloudflare R2
  static String get motionStorageMode =>
      dotenv.env['MOTION_STORAGE_MODE'] ?? 'r2';

  // Local path to MOTION_DICT folder (used when MOTION_STORAGE_MODE=local)
  static String get motionLocalPath =>
      dotenv.env['MOTION_LOCAL_PATH'] ?? '';

  static bool get useLocalMotionStorage => motionStorageMode == 'local';
}

