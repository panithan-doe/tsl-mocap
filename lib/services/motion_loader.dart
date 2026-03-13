import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/motion_models.dart';

class MotionData {
  final String word; // คำภาษาไทย
  final String variant; // variant ที่ใช้ (v1, v2, ...)
  final Map<String, dynamic> motionJson;
  final String overlayVideoUrl;
  final int totalFrames;
  final bool isStill; // true = ท่ายืนนิ่ง (ไม่กรอง frame)

  MotionData({
    required this.word,
    required this.variant,
    required this.motionJson,
    required this.overlayVideoUrl,
    required this.totalFrames,
    this.isStill = false,
  });

  /// Cache key สำหรับ word + variant
  String get cacheKey => '$word:$variant';
}

class MotionLoader {
  final String baseUrl;
  final String? localPath; // Path to local MOTION_DICT folder
  final bool useLocal; // true = use local files, false = use Cloudflare R2

  // In-memory cache (key = "word:variant")
  final Map<String, MotionData> _cache = {};

  // สระนำหน้าที่ต้องข้ามเพื่อหาพยัญชนะต้น
  static const Set<String> _leadingVowels = {'เ', 'แ', 'โ', 'ไ', 'ใ'};

  MotionLoader({
    required this.baseUrl,
    this.localPath,
    this.useLocal = false,
  });

  /// หาพยัญชนะต้นของคำไทย (ข้ามสระนำหน้า เ-, แ-, โ-, ไ-, ใ-)
  /// เช่น "เวียดนาม" → "ว", "แม่" → "ม", "กิน" → "ก"
  String _getInitialConsonant(String word) {
    if (word.isEmpty) return '';

    // ถ้าตัวแรกเป็นสระนำหน้า ให้ใช้ตัวที่ 2 (ถ้ามี)
    if (_leadingVowels.contains(word[0]) && word.length > 1) {
      return word[1];
    }
    return word[0];
  }

  /// Load motion data for a single Thai word with variant
  Future<MotionData?> loadMotion(String thaiWord, {String variant = 'v1'}) async {
    final cacheKey = '$thaiWord:$variant';

    // Check cache first
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    if (useLocal && localPath != null) {
      return _loadFromLocal(thaiWord, variant);
    }
    return _loadFromR2(thaiWord, variant);
  }

  /// Load motion from WordToken
  Future<MotionData?> loadMotionFromToken(WordToken token) async {
    if (token.isUnknown) {
      // Unknown word → load STILL pose
      return loadMotion('', variant: 'v1');
    }
    return loadMotion(token.word, variant: token.variant);
  }

  /// Load motion from local HTTP server
  Future<MotionData?> _loadFromLocal(String thaiWord, String variant) async {
    try {
      String motionJsonUrl;
      String overlayVideoUrl;
      bool isStill = false;

      // ถ้า thaiWord เป็น empty string → โหลด STILL.json (ท่ายืนนิ่ง)
      if (thaiWord.isEmpty) {
        motionJsonUrl = '$localPath/STILL.json';
        overlayVideoUrl = '';
        isStill = true;
      } else {
        // Path: {localPath}/{พยัญชนะต้น}/{คำ}/{variant}/motion.json
        final initialConsonant = _getInitialConsonant(thaiWord);
        motionJsonUrl = '$localPath/$initialConsonant/$thaiWord/$variant/motion.json';
        overlayVideoUrl = '$localPath/$initialConsonant/$thaiWord/$variant/overlay.mp4';
      }

      // Fetch motion.json via HTTP
      final response = await http.get(Uri.parse(motionJsonUrl));

      if (response.statusCode == 200) {
        final motionJson = jsonDecode(response.body) as Map<String, dynamic>;
        final totalFrames = motionJson['total_frames'] as int? ?? 0;

        final motionData = MotionData(
          word: isStill ? 'STILL' : thaiWord,
          variant: isStill ? 'v1' : variant,
          motionJson: motionJson,
          overlayVideoUrl: overlayVideoUrl,
          totalFrames: totalFrames,
          isStill: isStill,
        );

        // Cache the result
        _cache[motionData.cacheKey] = motionData;

        return motionData;
      } else {
        print('Local motion not found for $thaiWord ($variant): ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error loading local motion for $thaiWord ($variant): $e');
      return null;
    }
  }

  /// Load motion from Cloudflare R2
  Future<MotionData?> _loadFromR2(String thaiWord, String variant) async {
    try {
      String motionJsonUrl;
      String overlayVideoUrl;
      bool isStill = false;

      // ถ้า thaiWord เป็น empty string → โหลด STILL.json (ท่ายืนนิ่ง)
      if (thaiWord.isEmpty) {
        motionJsonUrl = '$baseUrl/MOTION_DICT_THAI/STILL.json';
        overlayVideoUrl = '';
        isStill = true;
      } else {
        // Path: MOTION_DICT_THAI/{พยัญชนะต้น}/{คำ}/{variant}/motion.json
        final initialConsonant = _getInitialConsonant(thaiWord);
        motionJsonUrl = '$baseUrl/MOTION_DICT_THAI/$initialConsonant/$thaiWord/$variant/motion.json';
        overlayVideoUrl = '$baseUrl/MOTION_DICT_THAI/$initialConsonant/$thaiWord/$variant/overlay.mp4';
      }

      // Fetch motion.json
      final response = await http.get(Uri.parse(motionJsonUrl));

      if (response.statusCode == 200) {
        final motionJson = jsonDecode(response.body) as Map<String, dynamic>;
        final totalFrames = motionJson['total_frames'] as int? ?? 0;

        final motionData = MotionData(
          word: isStill ? 'STILL' : thaiWord,
          variant: isStill ? 'v1' : variant,
          motionJson: motionJson,
          overlayVideoUrl: overlayVideoUrl,
          totalFrames: totalFrames,
          isStill: isStill,
        );

        // Cache the result
        _cache[motionData.cacheKey] = motionData;

        return motionData;
      } else {
        print('Failed to load motion for $thaiWord ($variant): ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error loading motion for $thaiWord ($variant): $e');
      return null;
    }
  }

  /// Load motion data for multiple WordTokens
  Future<List<MotionData>> loadMotionsFromTokens(List<WordToken> tokens) async {
    final List<MotionData> results = [];

    for (final token in tokens) {
      final motionData = await loadMotionFromToken(token);
      if (motionData != null) {
        results.add(motionData);
      }
    }

    return results;
  }

  /// Preload motions from WordTokens in parallel
  Future<List<MotionData>> preloadMotionsFromTokens(List<WordToken> tokens) async {
    final futures = tokens.map((token) => loadMotionFromToken(token));
    final results = await Future.wait(futures);
    return results.whereType<MotionData>().toList();
  }

  /// Legacy: Load motion data for multiple Thai words (backward compatibility)
  Future<List<MotionData>> loadMotions(List<String> thaiWords) async {
    final List<MotionData> results = [];

    for (final word in thaiWords) {
      final motionData = await loadMotion(word);
      if (motionData != null) {
        results.add(motionData);
      }
    }

    return results;
  }

  /// Legacy: Preload motions in parallel (backward compatibility)
  Future<List<MotionData>> preloadMotions(List<String> thaiWords) async {
    final futures = thaiWords.map((word) => loadMotion(word));
    final results = await Future.wait(futures);
    return results.whereType<MotionData>().toList();
  }

  /// Check if motion exists for a Thai word
  Future<bool> motionExists(String thaiWord, {String variant = 'v1'}) async {
    final cacheKey = '$thaiWord:$variant';
    if (_cache.containsKey(cacheKey)) {
      return true;
    }

    try {
      final String motionJsonUrl;
      final initialConsonant = _getInitialConsonant(thaiWord);
      if (useLocal && localPath != null) {
        motionJsonUrl = '$localPath/$initialConsonant/$thaiWord/$variant/motion.json';
      } else {
        motionJsonUrl = '$baseUrl/MOTION_DICT_THAI/$initialConsonant/$thaiWord/$variant/motion.json';
      }
      final response = await http.head(Uri.parse(motionJsonUrl));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
  }

  /// Get cached Thai words
  List<String> getCachedWords() {
    return _cache.keys.toList();
  }
}
