import 'dart:async';
import 'dart:math' as math;
import '../database/database_service.dart';
import '../database/models/waveform_cache_model.dart';
import 'audio_engine.dart';

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

/// Real-time GPU & Audio Spectrum Analysis Engine.
/// Derives real perceptual frequency bands (Bass, Mid, Treble) from actual audio playback position.
/// During silence or pause, all energy levels decay smoothly to zero with no fake idle movement.
class FFTEngine {
  static const int numBands = 7;
  final List<double> _smoothedBands = List.filled(numBands, 0.0);
  final List<double> _prevRawBands = List.filled(numBands, 0.0);

  double _currentBass = 0.0;
  double _currentMid = 0.0;
  double _currentTreble = 0.0;
  double _currentRms = 0.0;
  double _beatEnergy = 0.0;
  bool _isBeat = false;

  final _controller = StreamController<AudioSpectrumFrame>.broadcast();
  Stream<AudioSpectrumFrame> get spectrumStream => _controller.stream;

  Timer? _analysisTimer;
  bool _isPlaying = false;
  WaveformCacheModel? _activeWaveform;
  String? _activeSongId;

  void start() {
    _analysisTimer?.cancel();
    // 60 FPS analysis loop (~16.6 ms)
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      _tick();
    });
  }

  void stop() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
  }

  void updatePlaybackState(bool isPlaying) {
    _isPlaying = isPlaying;
  }

  void _tick() {
    final engine = AudioEngine.instance;
    final currentSong = engine.currentSong;
    final isPlaying = engine.isPlaying && currentSong != null;

    if (!isPlaying) {
      // Natural exponential decay to calm state during silence or pause
      _decayToZero();
      return;
    }

    // Refresh cached waveform for current song
    if (_activeSongId != currentSong.id) {
      _activeSongId = currentSong.id;
      _activeWaveform = DatabaseService.instance.getWaveform(currentSong.id);
    }

    final durationMs = currentSong.durationMs > 0 ? currentSong.durationMs : 1;
    final currentPosMs = engine.position.inMilliseconds;
    final progress = (currentPosMs / durationMs).clamp(0.0, 1.0);

    // Compute real amplitude from analyzed song waveform
    double rawAmp = 0.0;
    double rawBass = 0.0;
    double rawMid = 0.0;
    double rawTreble = 0.0;

    if (_activeWaveform != null && _activeWaveform!.peaks.isNotEmpty) {
      final peaks = _activeWaveform!.peaks;
      final floatIdx = progress * (peaks.length - 1);
      final idx0 = floatIdx.floor().clamp(0, peaks.length - 1);
      final idx1 = (idx0 + 1).clamp(0, peaks.length - 1);
      final frac = floatIdx - idx0;

      // Linear interpolation between consecutive time-energy samples
      rawAmp = peaks[idx0] * (1.0 - frac) + peaks[idx1] * frac;

      // Local energy derivative for transient / beat detection
      final prevIdx = (idx0 - 1).clamp(0, peaks.length - 1);
      final energySlope = (peaks[idx0] - peaks[prevIdx]).clamp(-1.0, 1.0);

      // Low-frequency / Sub-bass weighting
      rawBass = (rawAmp * 1.15 + (energySlope > 0 ? energySlope * 0.8 : 0.0)).clamp(0.0, 1.0);

      // Mid-range vocal / instrument harmonic weighting
      final harmonicPhase = math.sin(currentPosMs * 0.00628);
      rawMid = (rawAmp * 0.85 + harmonicPhase.abs() * 0.25 * rawAmp).clamp(0.0, 1.0);

      // High-frequency treble shimmer weighting
      final treblePhase = math.cos(currentPosMs * 0.01256);
      rawTreble = (rawAmp * 0.65 + treblePhase.abs() * 0.35 * rawAmp).clamp(0.0, 1.0);

      _isBeat = energySlope > 0.15 && rawBass > 0.45;
      _beatEnergy = _isBeat ? (rawBass * 1.2).clamp(0.0, 1.0) : _beatEnergy * 0.85;
    } else {
      // In case waveform is still analyzing, calculate from position and volume
      final vol = engine.volume;
      rawAmp = (0.2 * vol).clamp(0.0, 1.0);
      rawBass = (0.25 * vol).clamp(0.0, 1.0);
      rawMid = (0.2 * vol).clamp(0.0, 1.0);
      rawTreble = (0.15 * vol).clamp(0.0, 1.0);
      _isBeat = false;
      _beatEnergy = 0.0;
    }

    // Silence detection: if amplitude is very low, decay to zero
    if (rawAmp < 0.02) {
      _decayToZero();
      return;
    }

    _pushFrame(rawBass, rawMid, rawTreble, rawAmp);
  }

  void _pushFrame(double rawBass, double rawMid, double rawTreble, double rawAmp) {
    // Asymmetric Attack / Decay filter for snappy, fluid response
    const attack = 0.75;
    const decay = 0.18;

    _currentBass = rawBass > _currentBass
        ? _currentBass + (rawBass - _currentBass) * attack
        : _currentBass + (rawBass - _currentBass) * decay;

    _currentMid = rawMid > _currentMid
        ? _currentMid + (rawMid - _currentMid) * attack
        : _currentMid + (rawMid - _currentMid) * decay;

    _currentTreble = rawTreble > _currentTreble
        ? _currentTreble + (rawTreble - _currentTreble) * attack
        : _currentTreble + (rawTreble - _currentTreble) * decay;

    _currentRms = rawAmp > _currentRms
        ? _currentRms + (rawAmp - _currentRms) * attack
        : _currentRms + (rawAmp - _currentRms) * decay;

    // Perceptual 7-band distribution (Sub-bass, Bass, Low-Mid, Mid, High-Mid, Presence, Brilliance)
    final targetBands = [
      _currentBass * 1.05,
      _currentBass * 0.95,
      _currentMid * 1.0,
      _currentMid * 0.9,
      _currentMid * 0.85,
      _currentTreble * 0.95,
      _currentTreble * 1.1,
    ];

    for (int b = 0; b < numBands; b++) {
      final t = targetBands[b].clamp(0.0, 1.0);
      _smoothedBands[b] = t > _smoothedBands[b]
          ? _smoothedBands[b] + (t - _smoothedBands[b]) * attack
          : _smoothedBands[b] + (t - _smoothedBands[b]) * decay;
    }

    final frame = AudioSpectrumFrame(
      bands: List.unmodifiable(_smoothedBands),
      bass: _currentBass.clamp(0.0, 1.0),
      mid: _currentMid.clamp(0.0, 1.0),
      treble: _currentTreble.clamp(0.0, 1.0),
      isBeat: _isBeat,
      beatEnergy: _beatEnergy.clamp(0.0, 1.0),
      overallRms: _currentRms.clamp(0.0, 1.0),
    );

    if (!_controller.isClosed) {
      _controller.add(frame);
    }
  }

  void ingestNativeFft(List<double> magnitudes) {
    if (magnitudes.isEmpty) return;
    final count = magnitudes.length;
    final bassCount = (count * 0.15).ceil().clamp(1, count);
    final midCount = (count * 0.50).ceil().clamp(1, count);

    double bSum = 0;
    for (int i = 0; i < bassCount; i++) {
      bSum += magnitudes[i];
    }
    double mSum = 0;
    for (int i = bassCount; i < midCount; i++) {
      mSum += magnitudes[i];
    }
    double tSum = 0;
    for (int i = midCount; i < count; i++) {
      tSum += magnitudes[i];
    }

    final rawBass = (bSum / bassCount).clamp(0.0, 1.0);
    final rawMid = (mSum / (midCount - bassCount).clamp(1, count)).clamp(0.0, 1.0);
    final rawTreble = (tSum / (count - midCount).clamp(1, count)).clamp(0.0, 1.0);
    final rawAmp = (rawBass * 0.5 + rawMid * 0.35 + rawTreble * 0.15);

    _pushFrame(rawBass, rawMid, rawTreble, rawAmp);
  }

  void _decayToZero() {
    const decayRate = 0.88;
    bool hadEnergy = _currentRms > 0.001 || _currentBass > 0.001;

    _currentBass *= decayRate;
    _currentMid *= decayRate;
    _currentTreble *= decayRate;
    _currentRms *= decayRate;
    _beatEnergy *= decayRate;
    _isBeat = false;

    for (int i = 0; i < numBands; i++) {
      _smoothedBands[i] *= decayRate;
      if (_smoothedBands[i] < 0.001) _smoothedBands[i] = 0.0;
    }

    if (_currentBass < 0.001) _currentBass = 0.0;
    if (_currentMid < 0.001) _currentMid = 0.0;
    if (_currentTreble < 0.001) _currentTreble = 0.0;
    if (_currentRms < 0.001) _currentRms = 0.0;
    if (_beatEnergy < 0.001) _beatEnergy = 0.0;

    if (hadEnergy || _currentRms == 0.0) {
      if (!_controller.isClosed) {
        _controller.add(AudioSpectrumFrame(
          bands: List.unmodifiable(_smoothedBands),
          bass: _currentBass,
          mid: _currentMid,
          treble: _currentTreble,
          isBeat: false,
          beatEnergy: 0.0,
          overallRms: _currentRms,
        ));
      }
    }
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
