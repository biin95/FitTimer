import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../models/kegel_record.dart';

class KegelTrainingScreen extends StatefulWidget {
  final int tightenSeconds;
  final int relaxSeconds;
  final int rounds;

  const KegelTrainingScreen({
    super.key,
    required this.tightenSeconds,
    required this.relaxSeconds,
    required this.rounds,
  });

  @override
  State<KegelTrainingScreen> createState() => _KegelTrainingScreenState();
}

class _KegelTrainingScreenState extends State<KegelTrainingScreen> {
  static const _ttsChannel = MethodChannel('com.fittimer/tts');

  late int _remaining;
  int _currentRound = 0;
  bool _isTightening = true; // true=tighten, false=relax
  bool _isRunning = false;
  Timer? _timer;
  int _completedSets = 0;

  final DatabaseService _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ttsChannel.invokeMethod('stop');
    super.dispose();
  }

  void _startRound() {
    if (_currentRound >= widget.rounds) {
      _finishTraining();
      return;
    }
    _currentRound++;
    _isTightening = true;
    _remaining = widget.tightenSeconds;
    _isRunning = true;
    _speak('收紧');
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        _onPhaseComplete();
      }
    });
  }

  void _onPhaseComplete() {
    if (_isTightening) {
      // Tighten phase done -> switch to relax
      HapticFeedback.lightImpact();
      setState(() {
        _isTightening = false;
        _remaining = widget.relaxSeconds;
      });
      _speak('放松');
    } else {
      // Relax phase done -> round complete
      _timer?.cancel();
      setState(() {
        _completedSets++;
        _isRunning = false;
      });
      if (_currentRound < widget.rounds) {
        // Immediately start next round
        _startRound();
      } else {
        _finishTraining();
      }
    }
  }

  void _speak(String text) {
    try {
      _ttsChannel.invokeMethod('speak', {'text': text});
    } catch (_) {}
  }

  Future<void> _finishTraining() async {
    _timer?.cancel();
    _isRunning = false;

    if (_completedSets > 0 && mounted) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
      await _db.insertKegelRecord(KegelRecord(
        date: startOfDay,
        totalSets: widget.rounds,
        completedSets: _completedSets,
        createdAt: now.millisecondsSinceEpoch,
      ));
    }

    if (mounted) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop(_completedSets);
    }
  }

  void _skipToNext() {
    _timer?.cancel();
    _remaining = 0;
    _onPhaseComplete();
  }

  @override
  Widget build(BuildContext context) {
    final phase = _isTightening ? '收紧' : '放松';
    final phaseColor = _isTightening ? Colors.deepOrange : Colors.teal;
    final icon = _isTightening ? Icons.compress : Icons.self_improvement;

    return Scaffold(
      backgroundColor: phaseColor.withValues(alpha: 0.05),
      appBar: AppBar(
        title: Text('凯格尔训练 第 $_currentRound/${widget.rounds} 轮'),
        centerTitle: true,
        backgroundColor: phaseColor.withValues(alpha: 0.1),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _finishTraining,
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Phase icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                key: ValueKey(_isTightening),
                size: 80,
                color: phaseColor,
              ),
            ),
            const SizedBox(height: 24),

            // Phase label
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                phase,
                key: ValueKey('phase_$_isTightening'),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: phaseColor,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Countdown
            Text(
              '${_remaining ~/ 60}:${(_remaining % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w200,
                color: phaseColor,
              ),
            ),
            const SizedBox(height: 48),

            // Progress
            Text(
              '完成 $_completedSets/${widget.rounds} 组',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),

            // Round indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.rounds, (i) {
                final done = i < _completedSets;
                final current = i == _completedSets;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: current ? 16 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: done
                        ? phaseColor
                        : (current ? phaseColor.withValues(alpha: 0.5) : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(5),
                  ),
                );
              }),
            ),
            const SizedBox(height: 48),

            // Skip button
            if (_isRunning)
              OutlinedButton.icon(
                onPressed: _skipToNext,
                icon: const Icon(Icons.skip_next),
                label: Text(_isTightening ? '跳至放松' : '完成本轮'),
              ),
          ],
        ),
      ),
    );
  }
}
