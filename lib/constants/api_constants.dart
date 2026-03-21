import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  /// Get all Gemini API keys from .env (comma-separated)
  /// Example: GEMINI_API_KEYS=key1,key2,key3
  static List<String> get geminiApiKeys {
    final keysStr = dotenv.env['GEMINI_API_KEYS'] ?? '';
    if (keysStr.isEmpty) return [];

    return keysStr
        .split(',')
        .map((key) => key.trim())
        .where((key) => key.isNotEmpty)
        .toList();
  }

  /// Legacy support for single key (deprecated)
  static String get geminiApiKey {
    final keys = geminiApiKeys;
    return keys.isNotEmpty ? keys.first : '';
  }

  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  /// Build endpoint with specific API key
  static String geminiEndpointWithKey(String apiKey) => '$geminiBaseUrl?key=$apiKey';

  /// Legacy endpoint (uses first key)
  static String get geminiEndpoint => geminiEndpointWithKey(geminiApiKey);

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

  // Backend API URL for adding new words
  // Local dev: http://localhost:8000
  // Production: https://your-backend.railway.app
  static String get backendApiUrl =>
      dotenv.env['BACKEND_API_URL'] ?? 'http://localhost:8000';
}

