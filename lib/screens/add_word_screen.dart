import 'package:flutter/material.dart';
import '../services/backend_service.dart';

class AddWordScreen extends StatefulWidget {
  const AddWordScreen({super.key});

  @override
  State<AddWordScreen> createState() => _AddWordScreenState();
}

class _AddWordScreenState extends State<AddWordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _contextController = TextEditingController();
  final _videoUrlController = TextEditingController();

  bool _isSubmitting = false;
  String? _resultMessage;
  bool _isSuccess = false;
  bool _hasAddedWord = false; // Track if any word was added during this session

  // รายการ URL patterns ที่รองรับ
  static const List<String> _supportedSources = [
    'th-sl',      // th-sl.dict.th, www.th-sl.com
    'dic.ttrs',   // dic.ttrs.or.th
    'ttrs.or.th', // ttrs.or.th
    'youtube',    // youtube.com
    'youtu.be',   // youtu.be
  ];

  /// ตรวจสอบว่า URL มาจากแหล่งที่รองรับหรือไม่
  bool _isSupportedUrl(String url) {
    return _supportedSources.any((source) => url.contains(source));
  }

  final BackendService _backendService = BackendService();

  @override
  void dispose() {
    _wordController.dispose();
    _contextController.dispose();
    _videoUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitWord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
    });

    try {
      final result = await _backendService.addWord(
        word: _wordController.text.trim(),
        context: _contextController.text.trim(),
        videoUrl: _videoUrlController.text.trim(),
        sourceType: 'auto', // ระบบตรวจจับ source type อัตโนมัติจาก URL
      );

      setState(() {
        _isSubmitting = false;
        _isSuccess = result['status'] == 'SUCCESS' || result['status'] == 'PROCESSING';
        _resultMessage = result['message'] ??
            (_isSuccess
              ? 'เพิ่มคำ "${result['word']}" (${result['variant']}) สำเร็จ!'
              : 'เกิดข้อผิดพลาด');
      });

      if (_isSuccess) {
        _hasAddedWord = true; // Mark that a word was added
        // Clear form after success
        _wordController.clear();
        _contextController.clear();
        _videoUrlController.clear();
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _isSuccess = false;
        _resultMessage = 'เกิดข้อผิดพลาด: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _hasAddedWord);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
        title: const Text(
          'เพิ่มคำใหม่',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasAddedWord),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              _buildInfoCard(),

              const SizedBox(height: 24),

              // Form Card
              _buildFormCard(),

              const SizedBox(height: 24),

              // Result Message
              if (_resultMessage != null) _buildResultMessage(),

              const SizedBox(height: 24),

              // Submit Button
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Color(0xFF3B82F6),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'กรอกข้อมูลคำภาษามือที่ต้องการเพิ่ม ระบบจะประมวลผลวิดีโอและอัปโหลดอัตโนมัติ',
              style: TextStyle(
                color: Color(0xFF1E40AF),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word Input
          const Text(
            'คำภาษาไทย (Thai Gloss)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _wordController,
            decoration: _inputDecoration(
              hintText: 'เช่น เกิน, กิน, ครู',
              prefixIcon: Icons.text_fields,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกคำภาษาไทย';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Context Input
          const Text(
            'บริบท / ความหมาย (Context)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _contextController,
            decoration: _inputDecoration(
              hintText: 'เช่น มากเกินไป, exceed',
              prefixIcon: Icons.description_outlined,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกบริบท';
              }
              return null;
            },
          ),

          const SizedBox(height: 20),

          // Video URL Input
          const Text(
            'ลิงก์วิดีโอ (Video URL)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _videoUrlController,
            decoration: _inputDecoration(
              hintText: 'https://th-sl.dict.th/word/...',
              prefixIcon: Icons.link,
            ),
            keyboardType: TextInputType.url,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'กรุณากรอกลิงก์วิดีโอ';
              }
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return 'ลิงก์ต้องเริ่มต้นด้วย http:// หรือ https://';
              }
              // ตรวจสอบว่า URL มาจากแหล่งที่รองรับหรือไม่
              if (!_isSupportedUrl(value)) {
                return 'รองรับเฉพาะ: th-sl.dict.th, dic.ttrs.or.th, youtube.com';
              }
              return null;
            },
          ),

          // แสดงข้อความแหล่งที่รองรับ
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'รองรับ: th-sl.dict.th, dic.ttrs.or.th, youtube.com',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(prefixIcon, color: Colors.grey.shade400),
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
      ),
    );
  }

  Widget _buildResultMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isSuccess ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSuccess ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
            color: _isSuccess ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _resultMessage!,
              style: TextStyle(
                color: _isSuccess ? const Color(0xFF166534) : const Color(0xFF991B1B),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitWord,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF6EE7B7),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'เพิ่มคำใหม่',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
