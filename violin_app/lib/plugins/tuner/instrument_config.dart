class InstrumentConfig {
  final String name;
  final List<String> stringNames;
  final List<double> stringFreqs;
  final double a4Reference;

  const InstrumentConfig({
    required this.name,
    required this.stringNames,
    required this.stringFreqs,
    required this.a4Reference,
  });

  static const violin = InstrumentConfig(
    name: 'Violin',
    stringNames: ['G', 'D', 'A', 'E'],
    stringFreqs: [196.0, 293.66, 440.0, 659.25],
    a4Reference: 440.0,
  );

  static const all = [violin];

  String closestString(double frequency) {
    int closest = 0;
    double minDist = double.infinity;
    for (int i = 0; i < stringFreqs.length; i++) {
      final d = (frequency - stringFreqs[i]).abs();
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    return stringNames[closest];
  }
}
