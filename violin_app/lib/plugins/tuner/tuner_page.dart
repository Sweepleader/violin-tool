import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'widgets/pitch_display.dart';

class TunerPage extends StatefulWidget {
  const TunerPage({super.key});

  @override
  State<TunerPage> createState() => _TunerPageState();
}

class _TunerPageState extends State<TunerPage> {
  Timer? _timer;
  double _frequency = 440.0;
  String _noteName = 'A4';
  double _centsDeviation = 0.0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _updatePitch();
    });
  }

  void _updatePitch() {
    final randomDrift = Random().nextDouble() * 30 - 15;
    final freq = 440.0 + randomDrift;
    final centsOff = 1200 * log(freq / 440.0) / log(2);

    setState(() {
      _frequency = freq;
      _centsDeviation = centsOff;
      _noteName = 'A4';
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tuner')),
      body: Center(
        child: PitchDisplay(
          frequency: _frequency,
          noteName: _noteName,
          centsDeviation: _centsDeviation,
        ),
      ),
    );
  }
}
