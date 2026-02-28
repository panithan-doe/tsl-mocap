import 'dart:convert';
import 'package:http/http.dart' as http;

class MotionData {
  final String gloss;
  final Map<String, dynamic> motionJson;
  final String overlayVideoUrl;
  final int totalFrames;
  final bool isStill; // true = ท่ายืนนิ่ง (ไม่กรอง frame)

  MotionData({
    required this.gloss,
    required this.motionJson,
    required this.overlayVideoUrl,
    required this.totalFrames,
    this.isStill = false,
  });
}

class MotionLoader {
  final String baseUrl;

  // In-memory cache
  final Map<String, MotionData> _cache = {};

  MotionLoader({required this.baseUrl});

  /// Load motion data for a single gloss
  Future<MotionData?> loadMotion(String gloss) async {
    // Check cache first
    if (_cache.containsKey(gloss)) {
      return _cache[gloss];
    }

    try {
      String motionJsonUrl;
      String overlayVideoUrl;
      bool isStill = false;

      // ถ้า gloss เป็น empty string → โหลด STILL.json (ท่ายืนนิ่ง)
      if (gloss.isEmpty) {
        motionJsonUrl = '$baseUrl/MOTION_DICT_2/STILL.json';
        overlayVideoUrl = ''; // ไม่มี overlay สำหรับ STILL
        isStill = true;
      } else {
        // Get first letter for folder structure (A-Z)
        final firstLetter = gloss[0].toUpperCase();
        // Construct URLs: baseUrl/MOTION_DICT/{A-Z}/{GLOSS}/motion.json
        motionJsonUrl = '$baseUrl/MOTION_DICT_2/$firstLetter/$gloss/motion.json';
        overlayVideoUrl = '$baseUrl/MOTION_DICT_2/$firstLetter/$gloss/overlay.mp4';
      }

      // Fetch motion.json
      final response = await http.get(Uri.parse(motionJsonUrl));

      if (response.statusCode == 200) {
        final motionJson = jsonDecode(response.body) as Map<String, dynamic>;
        final totalFrames = motionJson['total_frames'] as int? ?? 0;

        final motionData = MotionData(
          gloss: isStill ? 'STILL' : gloss,
          motionJson: motionJson,
          overlayVideoUrl: overlayVideoUrl,
          totalFrames: totalFrames,
          isStill: isStill,
        );

        // Cache the result
        _cache[gloss] = motionData;

        return motionData;
      } else {
        print('Failed to load motion for $gloss: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error loading motion for $gloss: $e');
      return null;
    }
  }

  /// Load motion data for multiple glosses
  Future<List<MotionData>> loadMotions(List<String> glossList) async {
    final List<MotionData> results = [];

    for (final gloss in glossList) {
      final motionData = await loadMotion(gloss);
      if (motionData != null) {
        results.add(motionData);
      }
    }

    return results;
  }

  /// Preload motions in parallel for better performance
  Future<List<MotionData>> preloadMotions(List<String> glossList) async {
    final futures = glossList.map((gloss) => loadMotion(gloss));
    final results = await Future.wait(futures);
    return results.whereType<MotionData>().toList();
  }

  /// Check if motion exists for a gloss
  Future<bool> motionExists(String gloss) async {
    if (_cache.containsKey(gloss)) {
      return true;
    }

    try {
      final motionJsonUrl = '$baseUrl/motions/$gloss/motion.json';
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

  /// Get cached glosses
  List<String> getCachedGlosses() {
    return _cache.keys.toList();
  }
}
