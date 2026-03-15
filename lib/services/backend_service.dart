import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';

/// Service สำหรับเชื่อมต่อกับ Python Backend API
class BackendService {
  /// Base URL ของ Backend API
  String get baseUrl => ApiConstants.backendApiUrl;

  /// เพิ่มคำใหม่เข้าระบบ
  ///
  /// Parameters:
  /// - word: คำภาษาไทย (เช่น "เกิน")
  /// - context: บริบท/ความหมาย (เช่น "มากเกินไป")
  /// - videoUrl: URL ของวิดีโอ
  /// - sourceType: ประเภทแหล่งที่มา ("th-sl" หรือ "direct")
  ///
  /// Returns:
  /// Map with keys: status, word, variant, context, message, motion_url
  Future<Map<String, dynamic>> addWord({
    required String word,
    required String context,
    required String videoUrl,
    String sourceType = 'th-sl',
  }) async {
    final url = Uri.parse('$baseUrl/api/add-word');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'word': word,
          'context': context,
          'video_url': videoUrl,
          'source_type': sourceType,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['detail'] ?? 'Unknown error: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้ กรุณาตรวจสอบว่า Server กำลังทำงานอยู่');
      }
      rethrow;
    }
  }

  /// ดึงข้อมูลของคำ
  Future<Map<String, dynamic>> getWordInfo(String word) async {
    final url = Uri.parse('$baseUrl/api/word/$word');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get word info: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้');
      }
      rethrow;
    }
  }

  /// ดึงรายการคำทั้งหมด
  Future<List<String>> getAllWords() async {
    final url = Uri.parse('$baseUrl/api/words');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<String>.from(data['words'] ?? []);
      } else {
        throw Exception('Failed to get words: ${response.statusCode}');
      }
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception('ไม่สามารถเชื่อมต่อ Backend ได้');
      }
      rethrow;
    }
  }

  /// ตรวจสอบว่า motion.json มีอยู่หรือไม่
  Future<bool> checkMotionExists(String word, String variant) async {
    final url = Uri.parse('$baseUrl/api/check-motion/$word/$variant');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['exists'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// ตรวจสอบสถานะของ Backend
  Future<bool> healthCheck() async {
    final url = Uri.parse('$baseUrl/');

    try {
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
