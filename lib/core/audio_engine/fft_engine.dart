import 'dart:async';
import 'dart:math' as math;

class AudioSpectrumFrame {
  final List<double> bands; // 7 normalized perceptual bands (0.0 to 1.0)
  final double bass;        // 20Hz - 250Hz sub-bass/bass energy
  final double mid;         // 250Hz - 2000Hz vocal/harmonic energy
  final double treble;      // 2000Hz - 16000Hz shimmer/cymbal energy
  final bool isBeat;        // Beat onset detected
  final double beatEnergy;  // Beat intensity (0.0 to 1.0)
  final double overallRms;  // Overall track energy level

  const AudioSpectrumFrame({
    required this.bands,
    required this.bass,
    required this.mid,
    required this.treble,
    required this.isBeat,
    required this.beatEnergy,
    required this.overallRms,
  });

  static const empty = AudioSpectrumFrame(
    bands: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
    bass: 0.0,
    mid: 0.0,
    treble: 0.0,
    isBeat: false,
    beatEnergy: 0.0,
    overallRms: 0.0,
  );
}

class FFTEngine {
  static const int numBands = 7;
  final List<double> _smoothedBands = List.filled(numBands, 0.0);
  final List<double> _prevRawBands = List.filled(numBands, 0.0);
  final List<double> _fluxHistory = [];

  static const double _attackCoeff = 0.65;
  static const double _decayCoeff = 0.12;
  static const int _fluxWindowSize = 30;

  double _bassImpulse = 0.0;
  final _controller = StreamController<AudioSpectrumFrame>.broadcast();
  Stream<AudioSpectrumFrame> get spectrumStream => _controller.stream;

  Timer? _simulationTimer;
  bool _isPlaying = false;
  double _simTime = 0.0;

  void start() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (_isPlaying) {
        _simTime += 0.016;
        _generateSyntheticFrame(_simTime);
      } else {
        // Smoothly decay to zero when paused
        _decayToZero();
      }
    });
  }

  void stop() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  void updatePlaybackState(bool isPlaying) {
    _isPlaying = isPlaying;
  }

  // Ingest raw 512-point FFT magnitude bytes from native bridge (Android / Windows)
  void ingestNativeFft(List<double> rawMagnitudes) {
    if (rawMagnitudes.isEmpty) return;

    // Logarithmic bin pooling across 512 points
    final rawBands = _groupLogarithmicBands(rawMagnitudes);
    _processFrame(rawBands);
  }

  void _generateSyntheticFrame(double t) {
    // Highly organic procedural audio simulation based on rhythmic harmonics
    // Kick drum beat every 0.5s (~120 BPM)
    final double beatPhase = (t * 2.0) % 1.0;
    final double kickEnvelope = math.exp(-beatPhase * 8.0);
    final bool isBeat = kickEnvelope > 0.72;

    // Sub-bass & Bass
    final double subBass = (0.2 + 0.8 * kickEnvelope + 0.15 * math.sin(t * 3.1)).clamp(0.0, 1.0);
    final double bass = (0.25 + 0.65 * kickEnvelope + 0.2 * math.cos(t * 4.2)).clamp(0.0, 1.0);

    // Mid frequencies (Melodic movement)
    final double lowMid = (0.3 + 0.35 * math.sin(t * 5.0) + 0.2 * math.sin(t * 1.5)).clamp(0.0, 1.0);
    final double mid = (0.25 + 0.4 * math.sin(t * 7.2) + 0.15 * kickEnvelope).clamp(0.0, 1.0);
    final double upperMid = (0.2 + 0.35 * math.cos(t * 9.1) + 0.2 * math.sin(t * 2.7)).clamp(0.0, 1.0);

    // Treble (Hi-hats on 8th/16th notes)
    final double hiHatPhase = (t * 4.0) % 1.0;
    final double hiHatEnvelope = math.exp(-hiHatPhase * 14.0);
    final double presence = (0.15 + 0.45 * hiHatEnvelope + 0.15 * math.sin(t * 12.0)).clamp(0.0, 1.0);
    final double brilliance = (0.1 + 0.5 * hiHatEnvelope + 0.1 * math.cos(t * 15.0)).clamp(0.0, 1.0);

    final List<double> rawBands = [
      subBass,
      bass,
      lowMid,
      mid,
      upperMid,
      presence,
      brilliance,
    ];

    _processFrame(rawBands, forcedBeat: isBeat, forcedBeatEnergy: kickEnvelope);
  }

  void _processFrame(List<double> rawBands, {bool? forcedBeat, double? forcedBeatEnergy}) {
    // Attack / Decay Envelope smoothing per band
    for (int i = 0; i < numBands; i++) {
      final target = rawBands[i];
      if (target > _smoothedBands[i]) {
        _smoothedBands[i] += (target - _smoothedBands[i]) * _attackCoeff;
      } else {
        _smoothedBands[i] -= (_smoothedBands[i] - target) * _decayCoeff;
      }
    }

    // Spectral Flux Beat Detection over sub-bass & bass
    double flux = 0.0;
    for (int i = 0; i < 2; i++) {
      final diff = rawBands[i] - _prevRawBands[i];
      if (diff > 0) flux += diff;
      _prevRawBands[i] = rawBands[i];
    }

    _fluxHistory.add(flux);
    if (_fluxHistory.length > _fluxWindowSize) {
      _fluxHistory.removeAt(0);
    }

    final double meanFlux = _fluxHistory.reduce((a, b) => a + b) / _fluxHistory.length;
    final double dynamicThreshold = meanFlux * 1.35;
    final bool detectedBeat = forcedBeat ?? (flux > dynamicThreshold && flux > 0.12);
    final double beatIntensity = forcedBeatEnergy ?? (detectedBeat ? (flux / (dynamicThreshold + 0.001)).clamp(0.0, 1.0) : 0.0);

    // Bass impulse envelope with exponential decay
    if (detectedBeat) {
      _bassImpulse = 1.0;
    } else {
      _bassImpulse = (_bassImpulse - 0.06).clamp(0.0, 1.0);
    }

    final double bassAvg = (_smoothedBands[0] * 0.6 + _smoothedBands[1] * 0.4);
    final double midAvg = (_smoothedBands[2] * 0.3 + _smoothedBands[3] * 0.4 + _smoothedBands[4] * 0.3);
    final double trebleAvg = (_smoothedBands[5] * 0.5 + _smoothedBands[6] * 0.5);
    final double rms = _smoothedBands.reduce((a, b) => a + b) / numBands;

    _controller.add(
      AudioSpectrumFrame(
        bands: List.unmodifiable(_smoothedBands),
        bass: (bassAvg * 0.7 + _bassImpulse * 0.3).clamp(0.0, 1.0),
        mid: midAvg,
        treble: trebleAvg,
        isBeat: detectedBeat,
        beatEnergy: beatIntensity,
        overallRms: rms,
      ),
    );
  }

  void _decayToZero() {
    bool hasValue = false;
    for (int i = 0; i < numBands; i++) {
      if (_smoothedBands[i] > 0.005) {
        _smoothedBands[i] *= 0.85;
        hasValue = true;
      } else {
        _smoothedBands[i] = 0.0;
      }
    }
    _bassImpulse *= 0.85;

    if (hasValue) {
      _controller.add(
        AudioSpectrumFrame(
          bands: List.unmodifiable(_smoothedBands),
          bass: 0.0,
          mid: 0.0,
          treble: 0.0,
          isBeat: false,
          beatEnergy: 0.0,
          overallRms: 0.0,
        ),
      );
    }
  }

  List<double> _groupLogarithmicBands(List<double> fft) {
    // Maps 512 linear FFT bins to 7 log bands
    final bands = List.filled(numBands, 0.0);
    const splitIndices = [2, 6, 16, 48, 120, 260, 512];
    int start = 0;

    for (int b = 0; b < numBands; b++) {
      final end = splitIndices[b];
      double sum = 0.0;
      int count = 0;
      for (int i = start; i < end && i < fft.length; i++) {
        sum += fft[i];
        count++;
      }
      bands[b] = count > 0 ? (sum / count).clamp(0.0, 1.0) : 0.0;
      start = end;
    }
    return bands;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
