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

    final rng = Random();
    // Ornstein-Uhlenbeck: mean-reverting random walk for realistic jitter
    double cents = 0;
    double velocity = 0;
    int tick = 0;
    // Play different notes over time to show realistic step changes
    final notes = [('A4', 440.0), ('D5', 587.33), ('E5', 659.25), ('A4', 440.0)];
    int noteIdx = 0;
    int noteTicks = 0;

    _demoTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      tick++;
      noteTicks++;

      // Switch notes periodically to show distinct pitch steps
      if (noteTicks > 80 && noteIdx < notes.length - 1) {
        noteTicks = 0;
        noteIdx++;
      }

      final targetHz = notes[noteIdx].$2;

      // Ornstein-Uhlenbeck process for natural pitch variation
      // dv = -theta * v * dt + sigma * dW  (mean-reverting)
      final theta = 0.3;   // mean reversion speed
      final sigma = 4.0;   // noise intensity
      velocity += -theta * velocity * 0.08 + sigma * (rng.nextDouble() - 0.5);
      cents += velocity;

      // Clamp to realistic range
      if (cents > 30) cents = 30;
      if (cents < -30) cents = -30;
      // Mean-revert toward zero
      cents *= 0.98;

      // Occasional spike (string scratch, bow noise, YIN octave error)
      double spike = 0;
      if (rng.nextDouble() < 0.03) spike = (rng.nextDouble() - 0.5) * 50;

      final finalCents = cents + spike;
      final finalHz = targetHz * pow(2, finalCents / 1200);
      final conf = 0.85 + rng.nextDouble() * 0.12;

      setState(() {
        _history.add(PitchResult(
          note: notes[noteIdx].$1,
          frequency: finalHz,
          centsDeviation: finalCents,
          confidence: conf,
        ));
        if (_history.length > _maxHistory) _history.removeAt(0);
      });
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
