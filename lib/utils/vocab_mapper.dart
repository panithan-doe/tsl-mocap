import 'dart:convert';
import 'package:flutter/services.dart';

class VocabMapper {
  Map<String, String> _thaiToEnglish = {};
  List<String> _thaiWords = [];
  bool _isLoaded = false;

  Future<void> loadVocab() async {
    if (_isLoaded) return;

    final jsonString = await rootBundle.loadString('thai_eng_vocab.json');
    final List<dynamic> vocabList = jsonDecode(jsonString);

    for (final item in vocabList) {
      final thai = item['thai'] as String;
      final english = item['english'] as String;
      _thaiToEnglish[thai] = english;
      _thaiWords.add(thai);
    }

    _isLoaded = true;

  }

  List<String> get thaiWords => _thaiWords;

  List<String> mapThaiToEnglish(List<String> thaiWords) {
    return thaiWords.map((word) {
      // ถ้าเป็น empty string → ส่งต่อเป็น empty string (สำหรับ STILL animation)
      if (word.isEmpty) {
        return '';
      }
      return _thaiToEnglish[word] ?? 'UNKNOWN($word)';
    }).toList();
  }

  String? getEnglish(String thaiWord) {
    return _thaiToEnglish[thaiWord];
  }
}
