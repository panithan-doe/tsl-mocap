import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/motion_loader.dart';
import '../utils/vocab_mapper.dart';
import '../constants/api_constants.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _textController = TextEditingController();
  final VocabMapper _vocabMapper = VocabMapper();
  late final MotionLoader _motionLoader;

  List<String> _thaiTokens = [];
  List<String> _englishGloss = [];
  List<MotionData> _motionDataList = [];
  bool _isLoading = false;
  bool _isLoadingMotions = false;
  String? _errorMessage;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _motionLoader = MotionLoader(baseUrl: ApiConstants.cloudflareR2StorageBaseUrl);
    _initVocab();
  }

  Future<void> _initVocab() async {
    await _vocabMapper.loadVocab();
    setState(() {
      _isInitialized = true;
    });
  }

  Future<void> _processText() async {
    final inputText = _textController.text.trim();
    if (inputText.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณาใส่ข้อความ';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _thaiTokens = [];
      _englishGloss = [];
      _motionDataList = [];
    });

    try {
      // Step 1: Tokenize with Gemini
      final geminiService = GeminiService(validWords: _vocabMapper.thaiWords);
      final tokens = await geminiService.tokenize(inputText);
      final englishGloss = _vocabMapper.mapThaiToEnglish(tokens);

      setState(() {
        _thaiTokens = tokens;
        _englishGloss = englishGloss;
      });

      // Step 2: Auto-load motions
      setState(() {
        _isLoadingMotions = true;
      });

      final motions = await _motionLoader.preloadMotions(englishGloss);

      setState(() {
        _motionDataList = motions;
        _isLoading = false;
        _isLoadingMotions = false;
      });

      // แจ้งเตือนถ้ามี gloss ที่หา motion ไม่เจอ
      if (motions.length < englishGloss.length) {
        final missing = englishGloss
            .where((g) {
              // empty string → STILL
              final expectedGloss = g.isEmpty ? 'STILL' : g;
              return !motions.any((m) => m.gloss == expectedGloss);
            })
            .toList();
        if (missing.isNotEmpty) {
          setState(() {
            _errorMessage = 'ไม่พบ motion สำหรับ: ${missing.map((g) => g.isEmpty ? "(STILL)" : g).join(", ")}';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
        _isLoading = false;
        _isLoadingMotions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thai Sign Language Translator'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'ใส่ข้อความภาษาไทย',
                      hintText: 'เช่น ฉันกินข้าว',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _processText,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'ประมวลผล',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),
                  if (_thaiTokens.isNotEmpty) ...[
                    _buildResultCard(
                      title: 'Thai Tokens',
                      content: _thaiTokens.join(' | '),
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    _buildResultCard(
                      title: 'English Gloss',
                      content: _englishGloss.join(' | '),
                      color: Colors.green,
                    ),
                    const SizedBox(height: 16),
                    _buildResultCard(
                      title: 'Gloss List (JSON)',
                      content: _englishGloss.toString(),
                      color: Colors.purple,
                    ),
                    // แสดง loading indicator ขณะโหลด motion
                    if (_isLoadingMotions) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('กำลังโหลด Motion Data...'),
                          ],
                        ),
                      ),
                    ],
                  ],
                  if (_motionDataList.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Motion Data ที่โหลดได้:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._motionDataList.map((motion) => _buildMotionCard(motion)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlayerScreen(
                              motionDataList: _motionDataList,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.play_circle_filled, size: 28),
                      label: const Text(
                        'เล่น Animation',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildResultCard({
    required String title,
    required String content,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotionCard(MotionData motion) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                motion.gloss,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${motion.totalFrames} frames',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}
