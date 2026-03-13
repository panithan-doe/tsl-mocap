import 'package:flutter/material.dart';
import '../models/motion_models.dart';
import '../widgets/motion_player.dart';
import '../services/motion_loader.dart';
import '../utils/vocab_mapper.dart';

class PlayerScreen extends StatefulWidget {
  final List<MotionData> motionDataList;
  final List<WordToken> tokens;
  final MergedTokenSequence mergedSequence;
  final String originalText;

  const PlayerScreen({
    super.key,
    required this.motionDataList,
    required this.tokens,
    required this.mergedSequence,
    required this.originalText,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  MotionSequence? _sequence;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentClipIndex = 0; 

  // สร้าง Key สำหรับควบคุม MotionPlayer จากภายนอก
  final GlobalKey<MotionPlayerState> _playerKey = GlobalKey<MotionPlayerState>();

  @override
  void initState() {
    super.initState();
    _buildSequence();
  }

  void _buildSequence() {
    try {
      final clips = <MotionClip>[];

      for (final motionData in widget.motionDataList) {
        final clip = MotionClip.fromJson(
          motionData.motionJson,
          motionData.word,
          isStill: motionData.isStill,
        );
        clips.add(clip);
      }

      setState(() {
        _sequence = MotionSequence(clips: clips);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error building sequence: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
  backgroundColor: Colors.white,
  elevation: 0,
  centerTitle: true,
  
  // 1. เพิ่มพื้นที่ความกว้างให้ปุ่มมากขึ้น (จาก 180 เป็น 220)
  leadingWidth: 220, 
  
  leading: Padding(
    // 2. ลด Padding ซ้ายลงนิดหน่อยเพื่อคืนพื้นที่ให้ข้อความ
    padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8), 
    child: TextButton.icon(
      onPressed: () {
        Navigator.pop(context);
      },
      icon: const Icon(Icons.arrow_back_rounded, size: 18),
      label: const Text(
        'ทดสอบประโยคใหม่',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        // 3. บังคับให้อยู่บรรทัดเดียวเสมอ ถ้าล้นให้เป็น ... แทน
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF3B82F6),
        backgroundColor: Colors.blue.shade50.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  ),
  
  title: const Text(
    'Animation Player',
    style: TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 20,
      color: Color(0xFF1E293B),
    ),
  ),
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(1),
    child: Container(color: Colors.grey.shade200, height: 1),
  ),
),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            Text('กำลังเตรียม Animation...', style: TextStyle(color: Color(0xFF64748B))),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_sequence == null || _sequence!.clips.isEmpty) {
      return const Center(child: Text('ไม่มีข้อมูล Motion'));
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= 1. ส่วน Header (ข้อความต้นฉบับ + Chips) =================
          Row(
            crossAxisAlignment: CrossAxisAlignment.center, // จัดให้อยู่กลางแนวตั้ง
            children: [
              // เครื่องหมายคำพูดเปิด (ขนาดเล็กลง)
              Transform.flip(
                flipX: true,
                child: Icon(
                  Icons.format_quote_rounded,
                  color: Colors.blue.shade300,
                  size: 28, // ลดขนาดไอคอน
                ),
              ),
              const SizedBox(width: 12),
              
              // ข้อความต้นฉบับ
              Text(
                widget.originalText,
                style: const TextStyle(
                  fontSize: 26, // ลดขนาดตัวอักษรลงจาก 26 เป็น 20
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  height: 1.2,
                ),
                maxLines: 2, // จำกัดบรรทัดเพื่อคุมความสูง (ถ้าข้อความยาวมากจะขึ้น ...)
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(width: 12),
              
              // เครื่องหมายคำพูดปิด
              Icon(
                Icons.format_quote_rounded,
                color: Colors.blue.shade300,
                size: 28,
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          // --- ส่วนของ Chips Motion (คำภาษาไทย) ---
          
          Row(
            children: [
              const Text(
                'ลำดับคำภาษาไทย',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 8),
              // ตัว Tooltip สำหรับ Hover
              Tooltip(
                message: 'สีแดงคือคำที่ไม่มีใน Gloss Dictionary\nระบบจะทำการใช้ท่าทาง STILL ให้อัตโนมัติ',
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.redAccent, // ใช้สีแดงเพื่อให้ล้อกับความหมายของชิป
                  size: 18,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(widget.tokens.length, (index) {
              final token = widget.tokens[index];
              final isUnknown = token.isUnknown;
              final displayWord = token.word;

              final currentOriginalIndices = _currentClipIndex < widget.mergedSequence.originalIndices.length
                  ? widget.mergedSequence.originalIndices[_currentClipIndex]
                  : <int>[];
              final isCurrentlyPlaying = currentOriginalIndices.contains(index);

              Color bgColor;
              Color borderColor;
              Color textColor;
              Color numberBgColor;

              if (isUnknown) {
                bgColor = isCurrentlyPlaying ? Colors.red : Colors.red.shade50;
                borderColor = Colors.red;
                textColor = isCurrentlyPlaying ? Colors.white : Colors.red;
                numberBgColor = Colors.red;
              } else {
                bgColor = isCurrentlyPlaying ? Colors.blue.shade600 : Colors.blue.shade50;
                borderColor = Colors.blue.shade600;
                textColor = isCurrentlyPlaying ? Colors.white : Colors.blue.shade700;
                numberBgColor = Colors.blue.shade600;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: isCurrentlyPlaying ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: numberBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      displayWord,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isCurrentlyPlaying ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // ================= 2. ส่วน Content (ซ้าย 70% / ขวา 30%) =================
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ------ ฝั่งซ้าย: เครื่องเล่น Animation ------
                Expanded(
                  flex: 7, 
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: MotionPlayer(
                          key: _playerKey, // ใส่ Key เพื่อให้ข้างนอกสั่ง Seek ได้
                          sequence: _sequence!,
                          autoPlay: false,
                          thaiGroups: widget.mergedSequence.thaiGroups,
                          onClipChange: (clipIndex) {
                            setState(() {
                              _currentClipIndex = clipIndex;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 32),

                // ------ ฝั่งขวา: Table of Contents (Framestamp) ------
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // หัวตาราง + Info Cards (ย้ายมาตรงนี้)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ลำดับท่าทาง (Gloss Sequence)',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // --- Info Cards ฝั่งขวา (ใช้ Expanded ครอบเพื่อกันล้น) ---
                              Row(
                                children: [
                                  // กล่องที่ 1: Total Motions
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.accessibility_new_outlined, color: Color(0xFF3B82F6), size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Motions',
                                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                ),
                                                Text(
                                                  '${widget.tokens.length}',
                                                  style: const TextStyle(fontSize: 14, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(width: 12),
                                  
                                  // กล่องที่ 2: Total Frames
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(Icons.layers_outlined, color: Color(0xFF3B82F6), size: 16),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Frames',
                                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                                ),
                                                Text(
                                                  '${_sequence!.totalFrames}',
                                                  style: const TextStyle(fontSize: 14, color: Color(0xFF3B82F6), fontWeight: FontWeight.bold),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, thickness: 1),
                        
                        // ลิสต์รายการท่าทาง (Scrollable)
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _sequence!.clips.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            itemBuilder: (context, index) {
                              final clip = _sequence!.clips[index];
                              final isCurrent = index == _currentClipIndex;
                              // เช็คทั้งกรณีที่เป็นค่าว่าง และกรณีที่เป็นคำว่า STILL
                              final displayGloss = clip.gloss.isEmpty
                                  ? 'STILL' 
                                  : clip.gloss;                              
                              // ==========================================
                              // 1. คำนวณ Start Frame และ End Frame ด้วยตัวเอง
                              // ==========================================
                              int calculatedStartFrame = 0;
                              // วนลูปบวกจำนวนเฟรมของคลิปก่อนหน้าทั้งหมด
                              for (int i = 0; i < index; i++) {
                                // หากโค้ดคุณแจ้งเตือนที่ totalFrames ให้เปลี่ยนเป็น _sequence!.clips[i].frames.length แทนครับ
                                calculatedStartFrame += _sequence!.clips[i].totalFrames; 
                              }
                              
                              final int frameCount = clip.totalFrames; // จำนวนเฟรมของคลิปปัจจุบัน
                              final int calculatedEndFrame = calculatedStartFrame + frameCount - 1;
                              // ==========================================

                              return InkWell(
                                onTap: () {
                                  _playerKey.currentState?.seekTo(calculatedStartFrame);
                                },
                                child: Container(
                                  color: isCurrent ? Colors.blue.shade50.withOpacity(0.5) : Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), // ปรับ Vertical ให้กระชับขึ้น
                                  child: IntrinsicHeight( // ใช้ IntrinsicHeight เพื่อให้ Row สูงตามเนื้อหาจริง
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch, // ยืดให้ความสูงไอคอนเท่ากับความสูงตัวอักษร 3 บรรทัด
                                      children: [
                                        // --- กล่องไอคอนฝั่งซ้าย (ปรับเป็นจัตุรัส) ---
                                        AspectRatio(
                                          aspectRatio: 1.0, // บังคับให้ กว้าง : สูง เป็น 1 : 1 (จัตุรัส)
                                          child: Container(
                                            // ลบ width ออก เพื่อให้ AspectRatio เป็นตัวกำหนดจากความสูงของแถว (IntrinsicHeight)
                                            decoration: BoxDecoration(
                                              color: isCurrent ? Color(0xFF3B82F6) : Colors.blue.shade50.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Icon(
                                                isCurrent ? Icons.accessibility_new : Icons.accessibility_new_outlined,
                                                color: isCurrent ? Colors.white : Colors.blue.shade300,
                                                size: 24,
                                              ),
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(width: 16),
                                        
                                        // --- เนื้อหา 3 บรรทัดฝั่งขวา ---
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center, // จัดให้อยู่กึ่งกลางแนวตั้งของกล่องไอคอน
                                            children: [
                                              // บรรทัดที่ 1: ชื่อ Motion (ENG) + Badge
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      displayGloss,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                                        color: isCurrent ? const Color(0xFF1E293B) : const Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                  if (isCurrent) ...[
                                                    const SizedBox(width: 12),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.blue,
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: const Text(
                                                        'Playing',
                                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ]
                                                ],
                                              ),
                                              
                                              const SizedBox(height: 2), // ระยะห่างเล็กน้อยระหว่างบรรทัด
                                              
                                              // บรรทัดที่ 2: ชื่อคำไทย
                                              // if (thaiWord.isNotEmpty)
                                              //   Text(
                                              //     thaiWord,
                                              //     style: TextStyle(
                                              //       fontSize: 13, 
                                              //       color: isCurrent ? Colors.blue.shade700 : Colors.grey.shade600,
                                              //       fontWeight: isCurrent ? FontWeight.w500 : FontWeight.normal,
                                              //     ),
                                              //   ),
                                              
                                              const SizedBox(height: 2),
                                              
                                              // บรรทัดที่ 3: Framestamp
                                              Text(
                                                'Frame: ${calculatedStartFrame + 1} - ${calculatedEndFrame + 1} • $frameCount frames',
                                                style: TextStyle(
                                                  fontSize: 12, 
                                                  color: isCurrent ? Colors.blue.shade400 : Colors.grey.shade400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
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
}