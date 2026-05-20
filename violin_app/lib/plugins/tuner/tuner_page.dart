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
  final List<PitchResult> _history = [];
  static const _maxHistory = 60;
  bool _listening = false;
  String? _error;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startListening() async {
    setState(() => _error = null);
    final audio = ref.read(audioEngineProvider);
    _subscription = audio.pitchStream.listen((pitch) {
      setState(() {
        _history.add(pitch);
        if (_history.length > _maxHistory) _history.removeAt(0);
      });
    });
    try {
      await audio.start();
      setState(() => _listening = true);
    } catch (e) {
      setState(() => _error = 'Failed to start microphone: $e');
    }
  }

  void _toggleListening() {
    final audio = ref.read(audioEngineProvider);
    if (_listening) {
      audio.stop();
      _subscription?.cancel();
      setState(() {
        _listening = false;
        _history.clear();
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tuner'),
        actions: [
          if (_listening)
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _startListening,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _history.isNotEmpty
                ? PitchDisplay(history: _history)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic_none, size: 48,
                          color: theme.colorScheme.onSurface.withAlpha(80)),
                      const SizedBox(height: 16),
                      Text('Tap the mic icon to start',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(153),
                          )),
                    ],
                  ),
      ),
    );
  }
}
