/// A single landmark point from MediaPipe
class Landmark {
  final int location;
  final double x;
  final double y;
  final double z;
  final double visibility;

  Landmark({
    required this.location,
    required this.x,
    required this.y,
    required this.z,
    required this.visibility,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      location: json['landmark_location'] as int,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      z: (json['z'] as num).toDouble(),
      visibility: (json['visibility'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// A single frame containing pose and hand landmarks
class MotionFrame {
  final int frameIndex;
  final List<Landmark> pose;
  final List<Landmark> leftHand;
  final List<Landmark> rightHand;

  MotionFrame({
    required this.frameIndex,
    required this.pose,
    required this.leftHand,
    required this.rightHand,
  });

  factory MotionFrame.fromJson(Map<String, dynamic> json) {
    final coords = json['Image_Coordinates-(normalized_landmark)'] as Map<String, dynamic>;

    return MotionFrame(
      frameIndex: json['frame'] as int,
      pose: (coords['pose'] as List<dynamic>?)
              ?.map((e) => Landmark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      leftHand: (coords['left_hand'] as List<dynamic>?)
              ?.map((e) => Landmark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      rightHand: (coords['right_hand'] as List<dynamic>?)
              ?.map((e) => Landmark.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Complete motion clip data for one word/gloss
class MotionClip {
  final String gloss;
  final double fps;
  final int totalFrames;
  final int videoWidth;
  final int videoHeight;
  final List<MotionFrame> frames;

  MotionClip({
    required this.gloss,
    required this.fps,
    required this.totalFrames,
    required this.videoWidth,
    required this.videoHeight,
    required this.frames,
  });

  /// Get aspect ratio (width / height)
  double get aspectRatio => videoWidth / videoHeight;

  /// สร้าง MotionClip จาก JSON
  /// - isStill = true: ท่ายืนนิ่ง → เล่นทุก frame ไม่กรอง
  /// - isStill = false: ท่าปกติ → กรอง frame ที่ไม่มีมือออก
  factory MotionClip.fromJson(Map<String, dynamic> json, String gloss, {bool isStill = false}) {
    final motionData = json['motion_data'] as List<dynamic>;

    // แปลง JSON เป็น MotionFrame ทั้งหมดก่อน
    final allFrames = motionData
        .map((e) => MotionFrame.fromJson(e as Map<String, dynamic>))
        .toList();

    // กรอง frame ตาม logic Python:
    // - STILL (ท่ายืนนิ่ง): เล่นทุก frame
    // - ท่าปกติ: กรองเฉพาะ frame ที่มีมืออย่างน้อยหนึ่งข้าง
    final List<MotionFrame> filteredFrames;
    if (isStill) {
      // ท่ายืนนิ่ง: ใช้ทุก frame
      filteredFrames = allFrames;
    } else {
      // ท่าปกติ: กรอง frame ที่ไม่มีมือออก
      filteredFrames = allFrames
          .where((frame) => frame.leftHand.isNotEmpty || frame.rightHand.isNotEmpty)
          .toList();
    }

    return MotionClip(
      gloss: gloss,
      fps: (json['clip_fps'] as num?)?.toDouble() ?? 30.0,
      totalFrames: filteredFrames.length,
      videoWidth: json['video_width'] as int? ?? 600,
      videoHeight: json['video_height'] as int? ?? 600,
      frames: filteredFrames,
    );
  }
}

/// Sequence of multiple motion clips to play in order
class MotionSequence {
  final List<MotionClip> clips;

  MotionSequence({required this.clips});

  /// Total frames across all clips
  int get totalFrames => clips.fold(0, (sum, clip) => sum + clip.totalFrames);

  /// Get aspect ratio (use first clip's aspect ratio, default 1:1)
  double get aspectRatio => clips.isNotEmpty ? clips.first.aspectRatio : 1.0;

  /// Get frame at global index (across all clips)
  /// Returns the frame, clip index, and gloss name
  FrameInfo? getFrameAt(int globalIndex) {
    int currentIndex = 0;

    for (int i = 0; i < clips.length; i++) {
      final clip = clips[i];
      if (globalIndex < currentIndex + clip.totalFrames) {
        final localIndex = globalIndex - currentIndex;
        return FrameInfo(
          frame: clip.frames[localIndex],
          clipIndex: i,
          gloss: clip.gloss,
          aspectRatio: clip.aspectRatio,
        );
      }
      currentIndex += clip.totalFrames;
    }

    return null;
  }

  /// Get average FPS (use first clip's FPS)
  double get fps => clips.isNotEmpty ? clips.first.fps : 30.0;
}

/// Information about a frame in the sequence
class FrameInfo {
  final MotionFrame frame;
  final int clipIndex;
  final String gloss;
  final double aspectRatio;

  FrameInfo({
    required this.frame,
    required this.clipIndex,
    required this.gloss,
    this.aspectRatio = 1.0,
  });
}

/// Token ที่ได้จาก Gemini พร้อม variant ที่เลือก
class WordToken {
  final String word;
  final String variant;
  final bool isUnknown;

  WordToken({
    required this.word,
    required this.variant,
    this.isUnknown = false,
  });

  /// สร้างจาก JSON object {"word": "ครู", "variant": "v1"}
  factory WordToken.fromJson(Map<String, dynamic> json) {
    final word = json['word'] as String? ?? '';
    final variant = json['variant'] as String? ?? 'v1';
    final isUnknown = word.contains('[Unknown]') || json['unknown'] == true;

    return WordToken(
      word: isUnknown ? word.replaceAll(' [Unknown]', '').replaceAll('[Unknown]', '').trim() : word,
      variant: variant,
      isUnknown: isUnknown,
    );
  }

  /// สร้าง Unknown token
  factory WordToken.unknown(String word) {
    return WordToken(
      word: word.replaceAll(' [Unknown]', '').replaceAll('[Unknown]', '').trim(),
      variant: 'v1',
      isUnknown: true,
    );
  }

  /// แปลงเป็น JSON
  Map<String, dynamic> toJson() => {
    'word': word,
    'variant': variant,
    'unknown': isUnknown,
  };

  /// คำแสดงผล (รวม [Unknown] ถ้าเป็น unknown)
  String get displayWord => isUnknown ? '$word [Unknown]' : word;

  @override
  String toString() => 'WordToken(word: $word, variant: $variant, isUnknown: $isUnknown)';
}
