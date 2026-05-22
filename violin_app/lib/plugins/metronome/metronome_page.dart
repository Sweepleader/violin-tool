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
  Timer? _pollTimer; // only for UI sync

  void _toggle() {
    setState(() {
      _running = !_running;
      if (_running) {
        final bridge = AudioBridge.instance;
        bridge.outputStart();
        bridge.metroStart(_bpm, 44100);
        _startPoll();
      } else {
        _stop();
      }
    });
  }

  void _stop() {
    final bridge = AudioBridge.instance;
    bridge.metroStop();
    bridge.outputStop();
    _pollTimer?.cancel();
  }

  void _startPoll() {
    int lastBeatCount = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_running || !mounted) return;
      final count = AudioBridge.instance.metroBeatCount();
      if (count != lastBeatCount) {
        lastBeatCount = count;
        setState(() {
          _beatIndex = (count - 1) % 4; // C++ beats are 1-indexed after first
        });
      }
    });
  }

  void _setBpm(int bpm) {
    setState(() => _bpm = bpm);
    if (_running) {
      AudioBridge.instance.metroStart(_bpm, 44100);
    }
  }

  @override
  void dispose() {
    if (_running) _stop();
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
