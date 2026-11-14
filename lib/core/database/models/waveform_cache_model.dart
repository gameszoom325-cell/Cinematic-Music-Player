import 'dart:convert';

class WaveformCacheModel {
  final String songId;
  final List<double> peaks; // Normalized 0.0 to 1.0 amplitude values
  final double bpm;
  final int durationMs;
  final List<double> averageBands; // 7-band frequency balance profile
  final DateTime analyzedAt;

  const WaveformCacheModel({
    required this.songId,
    required this.peaks,
    required this.bpm,
    required this.durationMs,
    required this.averageBands,
    required this.analyzedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'songId': songId,
      'peaks': peaks,
      'bpm': bpm,
      'durationMs': durationMs,
      'averageBands': averageBands,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }

  factory WaveformCacheModel.fromMap(Map<String, dynamic> map) {
    return WaveformCacheModel(
      songId: map['songId'] as String,
      peaks: (map['peaks'] as List).map((e) => (e as num).toDouble()).toList(),
      bpm: (map['bpm'] as num).toDouble(),
      durationMs: map['durationMs'] as int,
      averageBands: (map['averageBands'] as List).map((e) => (e as num).toDouble()).toList(),
      analyzedAt: DateTime.parse(map['analyzedAt'] as String),
    );
  }

  String toJson() => json.encode(toMap());

  factory WaveformCacheModel.fromJson(String source) =>
      WaveformCacheModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
