import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'fft_engine.dart';

class NativeVisualizerBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.cinematic.music.player/visualizer');
  static const EventChannel _eventChannel =
      EventChannel('com.cinematic.music.player/visualizer_stream');

  final FFTEngine fftEngine;
  StreamSubscription? _fftSubscription;
  bool _isNativeActive = false;

  NativeVisualizerBridge({required this.fftEngine});

  Future<void> attachToSession(int audioSessionId) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Initialize Android Visualizer API
        final bool success = await _methodChannel.invokeMethod('attachVisualizer', {
          'audioSessionId': audioSessionId,
          'captureSize': 512,
        }) ?? false;

        if (success) {
          _isNativeActive = true;
          _listenToNativeFftStream();
        }
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        // Initialize Windows WASAPI loopback capture
        final bool success = await _methodChannel.invokeMethod('attachWasapiLoopback', {
          'captureSize': 512,
        }) ?? false;

        if (success) {
          _isNativeActive = true;
          _listenToNativeFftStream();
        }
      }
    } catch (e) {
      debugPrint("Native visualizer capture unavailable ($e). Fallback to organic synthesis.");
      _isNativeActive = false;
    }
  }

  void _listenToNativeFftStream() {
    _fftSubscription?.cancel();
    _fftSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic data) {
        if (data is List) {
          final magnitudes = data.map((e) => (e as num).toDouble()).toList();
          fftEngine.ingestNativeFft(magnitudes);
        }
      },
      onError: (err) {
        debugPrint("Native visualizer stream error: $err");
        _isNativeActive = false;
      },
    );
  }

  Future<void> detach() async {
    _fftSubscription?.cancel();
    _fftSubscription = null;
    try {
      if (_isNativeActive) {
        await _methodChannel.invokeMethod('detachVisualizer');
      }
    } catch (_) {}
    _isNativeActive = false;
  }
}
