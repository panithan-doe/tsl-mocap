import 'dart:async';
import 'package:flutter/material.dart';
import '../models/motion_models.dart';
import 'skeleton_painter.dart';

/// Widget that plays a sequence of motion clips as skeleton animation
class MotionPlayer extends StatefulWidget {
  final MotionSequence sequence;
  final bool autoPlay;
  final VoidCallback? onComplete;

  const MotionPlayer({
    super.key,
    required this.sequence,
    this.autoPlay = false,
    this.onComplete,
  });

  @override
  State<MotionPlayer> createState() => _MotionPlayerState();
}

class _MotionPlayerState extends State<MotionPlayer> {
  Timer? _timer;
  int _currentFrame = 0;
  bool _isPlaying = false;
  String _currentGloss = '';

  @override
  void initState() {
    super.initState();
    if (widget.sequence.clips.isNotEmpty) {
      _currentGloss = widget.sequence.clips.first.gloss;
    }
    if (widget.autoPlay) {
      _play();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
    });

    final fps = widget.sequence.fps;
    final frameDuration = Duration(milliseconds: (1000 / fps).round());

    _timer = Timer.periodic(frameDuration, (timer) {
      if (_currentFrame >= widget.sequence.totalFrames - 1) {
        _stop();
        widget.onComplete?.call();
        return;
      }

      setState(() {
        _currentFrame++;
        final frameInfo = widget.sequence.getFrameAt(_currentFrame);
        if (frameInfo != null) {
          _currentGloss = frameInfo.gloss;
        }
      });
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
    });
  }

  void _stop() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentFrame = 0;
      if (widget.sequence.clips.isNotEmpty) {
        _currentGloss = widget.sequence.clips.first.gloss;
      }
    });
  }

  void _seekTo(int frame) {
    setState(() {
      _currentFrame = frame.clamp(0, widget.sequence.totalFrames - 1);
      final frameInfo = widget.sequence.getFrameAt(_currentFrame);
      if (frameInfo != null) {
        _currentGloss = frameInfo.gloss;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final frameInfo = widget.sequence.getFrameAt(_currentFrame);
    final totalFrames = widget.sequence.totalFrames;

    return Column(
      children: [
        // Current gloss indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _currentGloss,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Skeleton canvas with correct aspect ratio
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: widget.sequence.aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: frameInfo != null
                      ? CustomPaint(
                          painter: SkeletonPainter(frame: frameInfo.frame),
                          size: Size.infinite,
                        )
                      : const Center(child: Text('No frame data')),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Progress bar
        Column(
          children: [
            Slider(
              value: _currentFrame.toDouble(),
              min: 0,
              max: (totalFrames - 1).toDouble(),
              onChanged: (value) => _seekTo(value.toInt()),
            ),
            Text(
              'Frame: $_currentFrame / ${totalFrames - 1}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: _stop,
              icon: const Icon(Icons.stop),
              iconSize: 32,
              color: Colors.red,
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: _isPlaying ? _pause : _play,
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              iconSize: 48,
              color: Colors.blue,
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: () => _seekTo(_currentFrame + 10),
              icon: const Icon(Icons.forward_10),
              iconSize: 32,
              color: Colors.grey,
            ),
          ],
        ),
      ],
    );
  }
}
