import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/motion_models.dart';

class GeminiService {
  final Map<String, dynamic> glossMap;

  /// validWords เก็บ keys ของ glossMap สำหรับ validation
  late final Set<String> _validWordsSet;

  GeminiService({required this.glossMap}) {
    _validWordsSet = glossMap.keys.toSet();
  }

  /// Tokenize ข้อความและ return List<WordToken> พร้อม variant ที่เลือก
  Future<List<WordToken>> tokenize(String inputText) async {
    final prompt = _buildPrompt(inputText);

    final response = await http.post(
      Uri.parse(ApiConstants.geminiEndpoint),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'topK': 1,
          'topP': 1,
          'maxOutputTokens': 8192,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String;
      print('=== GEMINI RESPONSE ===');
      print('Raw response: $text');
      final result = _parseResponse(text);
      print('Parsed result: $result');

      // Validate: ตรวจสอบและแก้ไขคำที่ไม่ถูกต้อง
      final validatedResult = _validateTokens(result);
      print('Validated result: $validatedResult');
      return validatedResult;
    } else {
      throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
    }
  }

  /// Validate WordToken ที่ Gemini return มา
  /// - ถ้า Gemini บอก unknown แต่คำมีใน glossMap → แก้เป็น known
  /// - ถ้าคำไม่มีใน glossMap → mark เป็น unknown
  /// - ถ้า variant ไม่มีจริง → fallback เป็น v1
  List<WordToken> _validateTokens(List<WordToken> tokens) {
    return tokens.map((token) {
      // ตรวจสอบว่าคำมีอยู่ใน glossMap หรือไม่
      final wordExists = _validWordsSet.contains(token.word);

      if (!wordExists) {
        // คำไม่มีใน vocabulary → mark เป็น unknown
        if (!token.isUnknown) {
          print('Word not in vocabulary: ${token.word} -> marking as unknown');
        }
        return WordToken.unknown(token.word);
      }

      // คำมีอยู่ใน vocabulary
      if (token.isUnknown) {
        // Gemini บอก unknown แต่คำมีจริง → แก้เป็น known
        print('Gemini marked "${token.word}" as unknown but it exists -> correcting to known');
      }

      // ตรวจสอบว่า variant มีอยู่จริงหรือไม่
      final wordVariants = glossMap[token.word] as Map<String, dynamic>?;
      String finalVariant = token.variant;
      if (wordVariants != null && !wordVariants.containsKey(token.variant)) {
        print('Variant ${token.variant} not found for ${token.word} -> fallback to v1');
        finalVariant = 'v1';
      }

      return WordToken(word: token.word, variant: finalVariant, isUnknown: false);
    }).toList();
  }

  String _buildPrompt(String inputText) {
    // ส่ง JSON ทั้งก้อนพร้อมบริบทของแต่ละคำ
    final glossMapJson = jsonEncode(glossMap);

    return '''
คุณคือผู้เชี่ยวชาญด้านภาษามือไทย (Thai Sign Language - TSL) และนักภาษาศาสตร์
หน้าที่ของคุณคือรับประโยคภาษาไทยทั่วไป และแปลงเป็น "ลำดับคำ (Gloss)" พร้อมเลือก variant ที่เหมาะสมกับบริบท

**กฎการทำงาน (Strict Rules):**
1. **ไวยากรณ์ (TSL Grammar):** ให้สลับตำแหน่งคำตามโครงสร้างภาษามือไทย มักเรียงลำดับเป็น: เวลา + สถานที่ + ประธาน + กรรม + กริยา + สรรพนาม (หรือ หัวเรื่อง + คำอธิบาย)
2. **ห้ามตัดคำประเภท คำนาม คำกริยา คำสรรพนาม และคำวิเศษณ์ ออกจากผลลัพธ์**
3. **ตัดคำฟุ่มเฟือย (Stopword Removal):** ห้ามใส่คำบุพบท, คำสันธาน, คำอุทาน, และคำลงท้าย (เช่น ครับ, ค่ะ, นะ, จ๊ะ) ลงในผลลัพธ์เด็ดขาด
4. **บังคับใช้คลังคำศัพท์ (Strict Vocabulary Matching):** คุณต้องเลือกใช้คำศัพท์ที่มี key อยู่ใน [Vocabulary JSON] เท่านั้น
5. **ถ้าคำใน inputText ตรงกับ key ใน JSON ให้เลือก key นั้นได้เลย**
6. **จัดการคำพ้องความหมาย (Synonyms):** หากผู้ใช้พิมพ์คำที่ไม่มีใน JSON แต่มีความหมายใกล้เคียงกับ key ให้แปลงเป็น key นั้น
7. **คำที่ไม่พบ (Unknown Word):** หากหาคำไม่ได้เลย ให้ใส่ "unknown": true

**การเลือก Variant:**
- แต่ละคำใน JSON มี variant (v1, v2, ...) พร้อมคำอธิบายบริบท
- **ถ้าบริบทมีความหมาย** (เช่น v1="ฝูงชน", v2="แยกย้ายกันไป") → วิเคราะห์ประโยคแล้วเลือก variant ที่เหมาะสม
- **ถ้าบริบทไม่มีความหมาย** (เช่น "ท่าที่ 1", "ท่าที่ 2", "ท่าปกติ") → **เลือก v1 เสมอ**

**รูปแบบผลลัพธ์ (Output Format):**
ตอบกลับเป็น JSON Array ของ Object เท่านั้น:
[
  {"word": "ครู", "variant": "v1"},
  {"word": "แยก", "variant": "v2"},
  {"word": "กรุงเทพ", "unknown": true}
]

- "word": คำภาษาไทยที่เลือก (key จาก JSON)
- "variant": variant ที่เลือก (v1, v2, ...)
- "unknown": true ถ้าหาคำไม่ได้

ห้ามพิมพ์ \`\`\`json หรือคำอธิบายใดๆ ทั้งสิ้น ตอบแค่ JSON Array เท่านั้น

**[Vocabulary JSON]:**
$glossMapJson

**ประโยคที่ต้องแปลง:**
"$inputText"
''';
  }

  /// Parse response จาก Gemini เป็น List<WordToken>
  List<WordToken> _parseResponse(String responseText) {
    // Clean the response text
    String cleaned = responseText.trim();

    // Remove markdown code blocks if present (handle various formats)
    // Pattern: ```json or ``` at start/end
    cleaned = cleaned.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*$', multiLine: true), '');
    cleaned = cleaned.trim();

    // Find JSON array - look for [ and ]
    final startIndex = cleaned.indexOf('[');
    final endIndex = cleaned.lastIndexOf(']');

    if (startIndex == -1) {
      throw Exception('No JSON array found. Cleaned response: $cleaned');
    }

    String jsonStr;
    if (endIndex == -1 || endIndex < startIndex) {
      // ไม่มี ] หรือ ] อยู่ก่อน [ → response อาจถูกตัด ให้ลองเพิ่ม ] เข้าไป
      print('Warning: JSON array may be incomplete, attempting to fix...');
      jsonStr = '${cleaned.substring(startIndex)}]';
    } else {
      jsonStr = cleaned.substring(startIndex, endIndex + 1);
    }

    try {
      final List<dynamic> parsed = jsonDecode(jsonStr);
      return parsed.map((item) {
        if (item is Map<String, dynamic>) {
          return WordToken.fromJson(item);
        } else if (item is String) {
          // Backward compatibility: ถ้าเป็น string ธรรมดา
          if (item.contains('[Unknown]')) {
            return WordToken.unknown(item);
          }
          return WordToken(word: item, variant: 'v1');
        }
        throw Exception('Unexpected item type: ${item.runtimeType}');
      }).toList();
    } catch (e) {
      // ลองแก้ไข JSON ที่ไม่สมบูรณ์ (object สุดท้ายถูกตัด)
      final fixedJson = _tryFixIncompleteJson(jsonStr);
      if (fixedJson != null) {
        try {
          final List<dynamic> parsed = jsonDecode(fixedJson);
          return parsed.map((item) {
            if (item is Map<String, dynamic>) {
              return WordToken.fromJson(item);
            } else if (item is String) {
              if (item.contains('[Unknown]')) {
                return WordToken.unknown(item);
              }
              return WordToken(word: item, variant: 'v1');
            }
            throw Exception('Unexpected item type: ${item.runtimeType}');
          }).toList();
        } catch (_) {
          // ยังไม่ได้อีก ให้ throw error เดิม
        }
      }
      throw Exception('JSON parse error: $e. Raw JSON: $jsonStr');
    }
  }

  /// พยายามแก้ไข JSON ที่ไม่สมบูรณ์ (ตัด object สุดท้ายที่ไม่สมบูรณ์ออก)
  String? _tryFixIncompleteJson(String jsonStr) {
    // หา comma สุดท้ายก่อน object ที่ไม่สมบูรณ์
    final lastCompleteObjectEnd = jsonStr.lastIndexOf('},');
    if (lastCompleteObjectEnd != -1) {
      // ตัดตรง }, แล้วเพิ่ม ] ปิด
      return '${jsonStr.substring(0, lastCompleteObjectEnd + 1)}]';
    }

    // หา } สุดท้าย
    final lastBrace = jsonStr.lastIndexOf('}');
    if (lastBrace != -1) {
      return '${jsonStr.substring(0, lastBrace + 1)}]';
    }

    return null;
  }
}
