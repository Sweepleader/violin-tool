import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_engine.dart';
import '../../core/services/providers.dart';
import 'widgets/pitch_display.dart';

class TunerPage extends ConsumerStatefulWidget {
  const TunerPage({super.key});

  @override
  ConsumerState<TunerPage> createState() => _TunerPageState();
}

class _TunerPageState extends ConsumerState<TunerPage> {
  StreamSubscription<PitchResult>? _subscription;
  Timer? _demoTimer;
  final List<PitchResult> _history = [];
  static const _maxHistory = 60;
  bool _listening = false;
  bool _demoMode = false;
  String? _error;

  @override
  void dispose() {
    _subscription?.cancel();
    _demoTimer?.cancel();
    super.dispose();
  }

  // ── Real microphone ──────────────────────────────────────────

  Future<void> _startListening() async {
    setState(() => _error = null);
    final audio = ref.read(audioEngineProvider);
    _subscription = audio.pitchStream.listen((pitch) {
      setState(() => _history.add(pitch));
      if (_history.length > _maxHistory) _history.removeAt(0);
    });
    try {
      await audio.start();
      setState(() => _listening = true);
    } catch (e) {
      setState(() => _error = 'Microphone error: $e');
    }
  }

  void _stopListening() {
    final audio = ref.read(audioEngineProvider);
    audio.stop();
    _subscription?.cancel();
    setState(() {
      _listening = false;
      _history.clear();
    });
  }

  // ── Demo mode (synthesized test signal) ──────────────────────

  void _startDemo() {
    _stopListening();
    setState(() {
      _demoMode = true;
      _history.clear();
      _error = null;
    });

    const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final rng = Random();
    double phase = 0;

    _demoTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      // Simulate A4 = 440Hz with vibrato (±10 cents) and slow drift
      final vibrato = sin(phase * 5) * 10;  // 5Hz vibrato, ±10 cents
      final drift = sin(phase * 0.3) * 8;   // slow drift
      final cents = vibrato + drift;
      final freq = 440.0 * pow(2, cents / 1200);
      // Occasional wild deviation (simulates bow change noise)
      final noise = rng.nextDouble() < 0.05 ? rng.nextDouble() * 30 - 15 : 0.0;
      final finalCents = cents + noise;
      final finalFreq = 440.0 * pow(2, finalCents / 1200);

      setState(() {
        _history.add(PitchResult(
          note: 'A4',
          frequency: finalFreq,
          centsDeviation: finalCents,
          confidence: 0.95,
        ));
        if (_history.length > _maxHistory) _history.removeAt(0);
      });
      phase += 0.08;
    });
  }

  void _stopDemo() {
    _demoTimer?.cancel();
    setState(() {
      _demoMode = false;
      _history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = _history.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuner'),
        actions: [
          if (_listening)
            Container(
              width: 10, height: 10,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
            ),
          // Demo button
          TextButton(
            onPressed: _demoMode ? _stopDemo : _startDemo,
            child: Text(_demoMode ? 'Stop' : 'Demo',
                style: TextStyle(color: theme.colorScheme.onPrimary)),
          ),
          // Mic button
          IconButton(
            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
            tooltip: _listening ? 'Stop mic' : 'Start mic',
            onPressed: _listening ? _stopListening : _startListening,
          ),
        ],
      ),
      body: Center(
        child: _error != null
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                ElevatedButton(
                    onPressed: _startListening, child: const Text('Retry')),
              ])
            : hasData
                ? PitchDisplay(history: _history)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.mic_none, size: 48,
                        color: theme.colorScheme.onSurface.withAlpha(80)),
                    const SizedBox(height: 16),
                    Text('Tap mic or Demo to start',
                        style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153))),
                  ]),
      ),
    );
  }
}
