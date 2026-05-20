import 'dart:async';
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
  PitchResult? _latestPitch;
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    final audio = ref.read(audioEngineProvider);
    _subscription = audio.pitchStream.listen((pitch) {
      setState(() => _latestPitch = pitch);
    });
    audio.start();
    _listening = true;
  }

  void _toggleListening() {
    final audio = ref.read(audioEngineProvider);
    if (_listening) {
      audio.stop();
      _subscription?.cancel();
      setState(() {
        _listening = false;
        _latestPitch = null;
      });
    } else {
      _startListening();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuner'),
        actions: [
          IconButton(
            icon: Icon(_listening ? Icons.mic : Icons.mic_off),
            onPressed: _toggleListening,
          ),
        ],
      ),
      body: Center(
        child: _latestPitch != null
            ? PitchDisplay(
                frequency: _latestPitch!.frequency,
                noteName: _latestPitch!.note,
                centsDeviation: _latestPitch!.centsDeviation,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_none, size: 64,
                      color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                  const SizedBox(height: 16),
                  const Text('Tap the mic icon to start'),
                ],
              ),
      ),
    );
  }
}
