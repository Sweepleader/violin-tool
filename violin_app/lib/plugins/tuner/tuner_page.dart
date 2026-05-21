import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_engine.dart';
import '../../core/services/providers.dart';
import 'instrument_config.dart';
import 'tuner_state.dart';
import 'widgets/pitch_display.dart';

class TunerPage extends ConsumerStatefulWidget {
  const TunerPage({super.key});

  @override
  ConsumerState<TunerPage> createState() => _TunerPageState();
}

class _TunerPageState extends ConsumerState<TunerPage> {
  StreamSubscription<PitchResult>? _subscription;
  Timer? _demoTimer;
  final _sm = TunerStateMachine();
  bool _listening = false;
  bool _demoMode = false;
  bool _strobeMode = false;
  String? _error;
  InstrumentConfig _instrument = InstrumentConfig.violin;

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
      _sm.feed(pitch);
      if (mounted) setState(() {});
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
    });
  }

  // ── Demo mode ─────────────────────────────────────────────────

  void _startDemo() {
    _stopListening();
    setState(() {
      _demoMode = true;
      _error = null;
    });

    final rng = Random();
    double cents = 0;
    double velocity = 0;
    final notes = [('A4', 440.0), ('D5', 587.33), ('E5', 659.25), ('A4', 440.0)];
    int noteIdx = 0;
    int noteTicks = 0;

    _demoTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      noteTicks++;
      if (noteTicks > 80 && noteIdx < notes.length - 1) {
        noteTicks = 0;
        noteIdx++;
      }
      final targetHz = notes[noteIdx].$2;
      velocity += -0.3 * velocity * 0.1 + 4.0 * (rng.nextDouble() - 0.5);
      cents += velocity;
      if (cents > 30) cents = 30;
      if (cents < -30) cents = -30;
      cents *= 0.98;
      double spike = 0;
      if (rng.nextDouble() < 0.03) spike = (rng.nextDouble() - 0.5) * 50;
      final finalCents = cents + spike;
      final finalHz = targetHz * pow(2, finalCents / 1200);

      _sm.feed(PitchResult(
        note: notes[noteIdx].$1,
        frequency: finalHz,
        centsDeviation: finalCents,
        confidence: 0.88 + rng.nextDouble() * 0.1,
      ));
      if (mounted) setState(() {});
    });
  }

  void _stopDemo() {
    _demoTimer?.cancel();
    setState(() => _demoMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSignal = _sm.state != TunerState.idle;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Tuner'),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<InstrumentConfig>(
                value: _instrument,
                items: InstrumentConfig.all
                    .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(c.name,
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onPrimary))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _instrument = v);
                },
                dropdownColor: theme.colorScheme.primary,
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        ),
        actions: [
          if (_listening)
            Container(
              width: 10, height: 10,
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
            ),
          TextButton(
            onPressed: _demoMode ? _stopDemo : _startDemo,
            child: Text(_demoMode ? 'Stop' : 'Demo',
                style: TextStyle(color: theme.colorScheme.onPrimary)),
          ),
          IconButton(
            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
            tooltip: _listening ? 'Stop mic' : 'Start mic',
            onPressed: _listening ? _stopListening : _startListening,
          ),
        ],
      ),
      body: Center(
        child: _error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: _startListening, child: const Text('Retry')),
                ]),
              )
            : hasSignal
                ? PitchDisplay(
                    sm: _sm,
                    instrument: _instrument,
                    strobeMode: _strobeMode,
                    onToggleMode: () =>
                        setState(() => _strobeMode = !_strobeMode),
                  )
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
