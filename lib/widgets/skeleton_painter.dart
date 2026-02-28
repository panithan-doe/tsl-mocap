import 'package:flutter/material.dart';
import '../models/motion_models.dart';

/// CustomPainter that draws a stick figure skeleton from MediaPipe landmarks
class SkeletonPainter extends CustomPainter {
  final MotionFrame frame;

  SkeletonPainter({required this.frame});

  // POSE_CONNECTIONS
  static const List<List<int>> poseConnections = [
    [1, 2], [2, 3], // ตาซ้ายฝั่งใน -> ชั้นนอก
    [4, 5], [5, 6], // ตาขวาฝั่งใน -> ฝั่งนอก
    [9, 10], // ปาก
    [11, 12], // ไหล่ซ้าย - ขวา
    [11, 13], [13, 15], // แขนซ้าย
    [12, 14], [14, 16], // แขนขวา
    [11, 23], // ลำตัวฝั่งซ้าย
    [12, 24], // ลำตัวฝั่งขวา
    [23, 24], // สะโพก
  ];

  // HAND_CONNECTIONS
  static const List<List<int>> handConnections = [
    [0, 1], [2, 5], [5, 9], [9, 13], [13, 17], [0, 17], // ฝ่ามือ
    [1, 2], [2, 3], [3, 4], // นิ้วโป้ง
    [5, 6], [6, 7], [7, 8], // นิ้วชี้
    [9, 10], [10, 11], [11, 12], // นิ้วกลาง
    [13, 14], [14, 15], [15, 16], // นิ้วนาง
    [17, 18], [18, 19], [19, 20], // นิ้วก้อย
  ];

  // Points ที่อยู่บนใบหน้า (วาดจุดเล็กกว่า)
  static const List<int> pointOnFaces = [0, 7, 8];

  // Points ที่เป็นมือใน pose (ไม่วาดเพราะจะวาดแยกใน hand)
  static const List<int> pointOnHand = [17, 18, 19, 20, 21, 22];

  // Pose colors
  static const Color posePointColor = Colors.blue;
  static const Color poseLineColor = Colors.lightBlue;

  // Left hand colors (เขียว)
  static const Color leftHandPointColor = Color(0xFF237223); // เขียวเข้ม (35,114,35)
  static const Color leftHandLineColor = Color(0xFF519A51); // เขียวอ่อน (81,154,81)

  // Right hand colors (ส้ม/เหลือง)
  static const Color rightHandPointColor = Color(0xFFFFAA00); // ส้ม/เหลือง (255,170,0)
  static const Color rightHandLineColor = Color(0xFFFFD786); // เหลืองอ่อน (255,215,134)

  @override
  void paint(Canvas canvas, Size size) {
    // Draw pose skeleton
    _drawPose(canvas, size, frame.pose);

    // Draw left hand (เขียว)
    if (frame.leftHand.isNotEmpty) {
      _drawHand(
        canvas,
        size,
        frame.leftHand,
        leftHandPointColor,
        leftHandLineColor,
      );
    }

    // Draw right hand (ส้ม)
    if (frame.rightHand.isNotEmpty) {
      _drawHand(
        canvas,
        size,
        frame.rightHand,
        rightHandPointColor,
        rightHandLineColor,
      );
    }
  }

  /// วาด Pose skeleton ตาม logic Python
  void _drawPose(Canvas canvas, Size size, List<Landmark> landmarks) {
    if (landmarks.isEmpty) return;

    // เก็บ pixel positions ของ pose points ที่ valid
    final Map<int, Offset> posePixels = {};

    // วาดจุด pose
    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      final px = lm.x * size.width;
      final py = lm.y * size.height;

      // ตรวจสอบว่าเป็น point บนใบหน้า
      if (pointOnFaces.contains(i)) {
        // วาดจุดเล็ก สำหรับใบหน้า
        final paint = Paint()
          ..color = posePointColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), 2, paint);
      } else if (i <= 24 && !pointOnHand.contains(i)) {
        // วาดเฉพาะ index <= 24 และไม่ใช่ point บนมือ
        // ตรวจสอบว่า px, py ไม่เป็น 0
        if (px != 0 && py != 0) {
          posePixels[i] = Offset(px, py);
          final paint = Paint()
            ..color = posePointColor
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(px, py), 4, paint);
        }
      }
    }

    // วาดเส้นเชื่อม pose
    final linePaint = Paint()
      ..color = poseLineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (final connection in poseConnections) {
      final pt1 = connection[0];
      final pt2 = connection[1];

      if (posePixels.containsKey(pt1) && posePixels.containsKey(pt2)) {
        canvas.drawLine(posePixels[pt1]!, posePixels[pt2]!, linePaint);
      }
    }
  }

  /// วาด Hand skeleton ตาม logic Python
  void _drawHand(
    Canvas canvas,
    Size size,
    List<Landmark> landmarks,
    Color pointColor,
    Color lineColor,
  ) {
    if (landmarks.isEmpty) return;

    // เก็บ pixel positions
    final Map<int, Offset> handPixels = {};

    // วาดจุด hand
    final pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      final px = lm.x * size.width;
      final py = lm.y * size.height;

      handPixels[i] = Offset(px, py);
      canvas.drawCircle(Offset(px, py), 3, pointPaint);
    }

    // วาดเส้นเชื่อม hand
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (final connection in handConnections) {
      final pt1 = connection[0];
      final pt2 = connection[1];

      if (handPixels.containsKey(pt1) && handPixels.containsKey(pt2)) {
        canvas.drawLine(handPixels[pt1]!, handPixels[pt2]!, linePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkeletonPainter oldDelegate) {
    return oldDelegate.frame != frame;
  }
}
