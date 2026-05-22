import 'dart:async';
import 'package:flutter/material.dart';
import '../../../ffi/audio_bridge.dart';
import 'widgets/metronome_display.dart';

class MetronomePage extends StatefulWidget {
  const MetronomePage({super.key});

  @override
  State<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends State<MetronomePage> {
  int _bpm = 120;
  bool _running = false;
  int _beatIndex = 0;
  Timer? _tickTimer;  // schedules buffer writes
  Timer? _pollTimer;  // polls render frame for UI sync

  // Scheduled beats: {targetRenderFrame, beatIndex}
  final List<_ScheduledBeat> _schedule = [];
  int _nextBeat = 0;
  int _writeFrame = 0; // last known render frame when we wrote a click

  void _toggle() {
    setState(() {
      _running = !_running;
      if (_running) {
        _beatIndex = 0;
        _schedule.clear();
        _writeFrame = AudioBridge.instance.outputFrame();
        _startOutput();
        _startTicks();
        _startPoll();
      } else {
        _stopOutput();
        _tickTimer?.cancel();
        _pollTimer?.cancel();
      }
    });
  }

  void _startOutput() {
    AudioBridge.instance.outputStart();
  }

  void _stopOutput() {
    AudioBridge.instance.outputStop();
  }

  // Step 1: Timer fires → write click to buffer, record target frame
  void _startTicks() {
    final intervalMs = (60000 ~/ _bpm);
    _tickTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      AudioBridge.instance.playClick(44100, 1.0);
      // Record the approximate frame when this click was written.
      // WASAPI latency ≈ buffer size (~20ms = ~880 frames at 44.1kHz).
      // The click will be audible when render_frame ≈ _writeFrame + latency.
      final latencyFrames = 44100 * 20 ~/ 1000; // ~20ms
      final targetFrame = _writeFrame + latencyFrames;
      _schedule.add(_ScheduledBeat(targetFrame, _nextBeat % 4));
      _nextBeat++;
      _writeFrame = targetFrame;
    });
  }

  // Step 2: Poll render frame → update UI when audio reaches each beat
  void _startPoll() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 5), (_) {
      if (!_running) return;
      final currentFrame = AudioBridge.instance.outputFrame();
      while (_schedule.isNotEmpty &&
          _schedule.first.targetFrame <= currentFrame) {
        final beat = _schedule.removeAt(0);
        if (mounted) {
          setState(() => _beatIndex = beat.beatIndex);
        }
      }
    });
  }

  void _setBpm(int bpm) {
    setState(() => _bpm = bpm);
    if (_running) {
      _schedule.clear();
      _tickTimer?.cancel();
      _startTicks();
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _pollTimer?.cancel();
    if (_running) _stopOutput();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metronome')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MetronomeDisplay(
              bpm: _bpm,
              active: _running,
              beatIndex: _beatIndex,
            ),
            const SizedBox(height: 32),
            Text('$_bpm BPM',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Slider(
              value: _bpm.toDouble(),
              min: 40,
              max: 208,
              onChanged: (v) => _setBpm(v.round()),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _toggle,
              icon: Icon(_running ? Icons.stop : Icons.play_arrow),
              label: Text(_running ? 'Stop' : 'Start'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledBeat {
  final int targetFrame;
  final int beatIndex;
  _ScheduledBeat(this.targetFrame, this.beatIndex);
}
