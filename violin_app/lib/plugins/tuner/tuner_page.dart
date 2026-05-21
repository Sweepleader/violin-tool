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
    // Demo phases: flat→tune up→inTune(hold)→sharp→back→change note
    final notes = [('A4', 440.0), ('D5', 587.33), ('A4', 440.0)];
    int noteIdx = 0;
    int tick = 0;
    double cents = -25; // start flat

    // Pre-computed trajectory for realistic tuning simulation
    // Phase: 0=flat drift, 1=approaching, 2=inTune hold, 3=overshoot, 4=return
    int phase = 0;
    int phaseTick = 0;

    _demoTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      tick++;
      phaseTick++;
      final targetHz = notes[noteIdx].$2;

      // State machine for realistic tuning behavior
      if (phase == 0 && phaseTick > 30) { phase = 1; phaseTick = 0; } // drift→approach
      if (phase == 1 && phaseTick > 40) { phase = 2; phaseTick = 0; } // approach→inTune
      if (phase == 2 && phaseTick > 50) { phase = 3; phaseTick = 0; } // inTune→overshoot
      if (phase == 3 && phaseTick > 20) { phase = 4; phaseTick = 0; } // overshoot→return
      if (phase == 4 && phaseTick > 30) { // return→next note
        phase = 0; phaseTick = 0;
        noteIdx = (noteIdx + 1) % notes.length;
        cents = -25;
      }

      // Cents target per phase
      double targetCents;
      switch (phase) {
        case 0: targetCents = -20 + rng.nextDouble() * 5; break; // flat, slightly unstable
        case 1: targetCents = -20 + 20 * (phaseTick / 40.0); break; // linear approach
        case 2: targetCents = (rng.nextDouble() - 0.5) * 1.5; break; // in-tune, ±1.5¢
        case 3: targetCents = 5 + rng.nextDouble() * 3; break; // slight overshoot
        case 4: targetCents = 5 - 5 * (phaseTick / 30.0); break; // return to in-tune
        default: targetCents = 0;
      }

      // Smooth approach to target (simulates musician adjusting)
      cents += (targetCents - cents) * 0.15;
      // Tiny natural jitter (±0.3¢)
      final finalCents = cents + (rng.nextDouble() - 0.5) * 0.6;
      final finalHz = targetHz * pow(2, finalCents / 1200);

      final conf = phase == 2 ? 0.92 + rng.nextDouble() * 0.06  // in-tune: high conf
          : phase == 1 || phase == 4 ? 0.85 + rng.nextDouble() * 0.1
          : 0.82 + rng.nextDouble() * 0.08;

      _sm.feed(PitchResult(
        note: notes[noteIdx].$1,
        frequency: finalHz,
        centsDeviation: finalCents,
        confidence: conf,
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
