import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
  bool _hasAddedWord = false;

  // Video source mode: true = URL, false = File Upload
  bool _useUrlMode = true;

  // File upload state
  String? _selectedFileName;
  Uint8List? _selectedFileBytes;

  // รายการ URL patterns ที่รองรับ
  static const List<String> _supportedSources = [
    'th-sl',
    'dic.ttrs',
    'ttrs.or.th',
    'youtube',
    'youtu.be',
  ];

  // รูปแบบไฟล์ที่รองรับ
  static const List<String> _supportedExtensions = ['mp4', 'mov', 'avi', 'webm'];

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

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions,
        withData: true, // Required for web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedFileName = file.name;
            _selectedFileBytes = file.bytes;
            _resultMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _resultMessage = 'เกิดข้อผิดพลาดในการเลือกไฟล์: $e';
        _isSuccess = false;
      });
    }
  }

  void _clearSelectedFile() {
    setState(() {
      _selectedFileName = null;
      _selectedFileBytes = null;
    });
  }

  Future<void> _submitWord() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate file if in upload mode
    if (!_useUrlMode && _selectedFileBytes == null) {
      setState(() {
        _resultMessage = 'กรุณาเลือกไฟล์วิดีโอ';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _resultMessage = null;
    });

    try {
      Map<String, dynamic> result;

      if (_useUrlMode) {
        // URL mode
        result = await _backendService.addWord(
          word: _wordController.text.trim(),
          context: _contextController.text.trim(),
          videoUrl: _videoUrlController.text.trim(),
          sourceType: 'auto',
        );
      } else {
        // File upload mode
        result = await _backendService.addWordWithFile(
          word: _wordController.text.trim(),
          context: _contextController.text.trim(),
          fileBytes: _selectedFileBytes!,
          fileName: _selectedFileName!,
        );
      }

      setState(() {
        _isSubmitting = false;
        _isSuccess = result['status'] == 'SUCCESS' || result['status'] == 'PROCESSING';
        _resultMessage = result['message'] ??
            (_isSuccess
                ? 'เพิ่มคำ "${result['word']}" (${result['variant']}) สำเร็จ!'
                : 'เกิดข้อผิดพลาด');
      });

      if (_isSuccess) {
        _hasAddedWord = true;
        _wordController.clear();
        _contextController.clear();
        _videoUrlController.clear();
        _clearSelectedFile();
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
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildFormCard(),
                const SizedBox(height: 24),
                if (_resultMessage != null) _buildResultMessage(),
                const SizedBox(height: 24),
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

          // Video Source Toggle
          const Text(
            'แหล่งที่มาวิดีโอ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          _buildVideoSourceToggle(),

          const SizedBox(height: 16),

          // Conditional: URL Input or File Upload
          if (_useUrlMode) _buildUrlInput() else _buildFileUpload(),
        ],
      ),
    );
  }

  Widget _buildVideoSourceToggle() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _useUrlMode = true;
                  _resultMessage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _useUrlMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _useUrlMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.link,
                      size: 18,
                      color: _useUrlMode
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ลิงก์ URL',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _useUrlMode
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _useUrlMode = false;
                  _resultMessage = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_useUrlMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: !_useUrlMode
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 18,
                      color: !_useUrlMode
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'อัปโหลดไฟล์',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: !_useUrlMode
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrlInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          validator: _useUrlMode
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'กรุณากรอกลิงก์วิดีโอ';
                  }
                  if (!value.startsWith('http://') &&
                      !value.startsWith('https://')) {
                    return 'ลิงก์ต้องเริ่มต้นด้วย http:// หรือ https://';
                  }
                  if (!_isSupportedUrl(value)) {
                    return 'รองรับเฉพาะ: th-sl.dict.th, dic.ttrs.or.th, youtube.com';
                  }
                  return null;
                }
              : null,
        ),
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
    );
  }

  Widget _buildFileUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ไฟล์วิดีโอ',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),

        // File picker area
        if (_selectedFileName == null)
          GestureDetector(
            onTap: _pickVideoFile,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  style: BorderStyle.solid,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      color: Color(0xFF3B82F6),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'คลิกเพื่อเลือกไฟล์วิดีโอ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'รองรับ: MP4, MOV, AVI, WebM (สูงสุด 100MB)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Selected file display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.videocam,
                    color: Color(0xFF10B981),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedFileName!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF166534),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${(_selectedFileBytes!.length / (1024 * 1024)).toStringAsFixed(2)} MB',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _clearSelectedFile,
                  icon: const Icon(
                    Icons.close,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        // Change file button if file is selected
        if (_selectedFileName != null)
          TextButton.icon(
            onPressed: _pickVideoFile,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('เลือกไฟล์อื่น'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
            ),
          ),
      ],
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
