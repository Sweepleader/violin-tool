import 'dart:async';
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
  final _sm = TunerStateMachine();
  AudioEngine? _audio; // captured in initState for dispose safety
  bool _listening = false;
  bool _strobeMode = false;
  String? _error;
  InstrumentConfig _instrument = InstrumentConfig.violin;

  @override
  void initState() {
    super.initState();
    _audio = ref.read(audioEngineProvider);
    // Defer past frame cycle to avoid FFI scheduler crash
    Future.microtask(_startListening);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _audio?.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() => _error = null);
    final audio = _audio!;
    // Ensure clean state before starting
    await audio.stop();
    _subscription?.cancel();
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

  void _toggleListening() {
    final audio = _audio!;
    if (_listening) {
      audio.stop();
      _subscription?.cancel();
      setState(() => _listening = false);
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          IconButton(
            icon: Icon(_listening ? Icons.mic : Icons.mic_none),
            tooltip: _listening ? 'Stop' : 'Start',
            onPressed: _toggleListening,
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
            : PitchDisplay(
                sm: _sm,
                instrument: _instrument,
                strobeMode: _strobeMode,
                onToggleMode: () =>
                    setState(() => _strobeMode = !_strobeMode),
              ),
      ),
    );
  }
}
