import 'dart:async';
import 'audio_reactive_analyzer.dart';

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

  factory AudioSpectrumFrame.fromReactive(AudioReactiveFrame frame) {
    final b = frame.bass;
    final m = frame.vocals;
    final t = frame.drums;
    return AudioSpectrumFrame(
      bands: [b * 1.1, b * 0.95, m * 1.0, m * 0.9, m * 0.85, t * 0.9, t * 1.05],
      bass: frame.bass,
      mid: frame.vocals,
      treble: frame.drums,
      isBeat: frame.drums > 0.35,
      beatEnergy: frame.drums,
      overallRms: frame.amplitude,
    );
  }
}

/// Backwards-compatible facade over [AudioReactiveAnalyzer].
class FFTEngine {
  static const int numBands = 7;
  final AudioReactiveAnalyzer _analyzer = AudioReactiveAnalyzer.instance;
  StreamSubscription<AudioReactiveFrame>? _sub;

  final StreamController<AudioSpectrumFrame> _controller =
      StreamController<AudioSpectrumFrame>.broadcast();
  Stream<AudioSpectrumFrame> get spectrumStream => _controller.stream;

  FFTEngine() {
    _sub = _analyzer.frameStream.listen((frame) {
      if (!_controller.isClosed) {
        _controller.add(AudioSpectrumFrame.fromReactive(frame));
      }
    });
  }

  void start() => _analyzer.wake();
  void stop() => _analyzer.sleep();
  void updatePlaybackState(bool isPlaying) {
    if (isPlaying) {
      _analyzer.wake();
    } else {
      _analyzer.sleep();
    }
  }

  void ingestNativeFft(List<double> magnitudes) {}

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
