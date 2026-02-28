import 'package:flutter/material.dart';
import '../models/motion_models.dart';
import '../widgets/motion_player.dart';
import '../services/motion_loader.dart';

/// Screen that plays skeleton animation for a sequence of glosses
class PlayerScreen extends StatefulWidget {
  final List<MotionData> motionDataList;

  const PlayerScreen({
    super.key,
    required this.motionDataList,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  MotionSequence? _sequence;
  bool _isLoading = true;
  String? _errorMessage;

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
          motionData.gloss,
          isStill: motionData.isStill, // ส่ง flag isStill เพื่อควบคุมการกรอง frame
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
      appBar: AppBar(
        title: const Text('Animation Player'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ],
          ),
        ),
      );
    }

    if (_sequence == null || _sequence!.clips.isEmpty) {
      return const Center(child: Text('No motion data available'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Sequence info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoItem(
                    'Clips',
                    '${_sequence!.clips.length}',
                    Icons.movie,
                  ),
                  _buildInfoItem(
                    'Total Frames',
                    '${_sequence!.totalFrames}',
                    Icons.layers,
                  ),
                  _buildInfoItem(
                    'FPS',
                    '${_sequence!.fps.toStringAsFixed(0)}',
                    Icons.speed,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gloss sequence
          Wrap(
            spacing: 8,
            children: _sequence!.clips.map((clip) {
              return Chip(
                label: Text(clip.gloss),
                backgroundColor: Colors.blue.shade50,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Motion player
          Expanded(
            child: MotionPlayer(
              sequence: _sequence!,
              autoPlay: false,
              onComplete: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Animation completed!')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}
