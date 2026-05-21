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
  Timer? _timer;

  void _toggle() {
    setState(() {
      _running = !_running;
      if (_running) {
        _beatIndex = 0;
        AudioBridge.instance.outputStart();
        _startTicks();
      } else {
        _stopOutput();
        _timer?.cancel();
      }
    });
  }

  void _stopOutput() {
    AudioBridge.instance.outputStop();
  }

  void _startTicks() {
    final intervalMs = (60000 ~/ _bpm);
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      AudioBridge.instance.playClick(44100, 1.0);
      setState(() {
        _beatIndex = (_beatIndex + 1) % 4;
      });
    });
  }

  void _setBpm(int bpm) {
    setState(() => _bpm = bpm);
    if (_running) {
      _timer?.cancel();
      _startTicks();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
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
