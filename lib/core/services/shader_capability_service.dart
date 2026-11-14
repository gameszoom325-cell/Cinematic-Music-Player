import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Proactively tests Android and Windows GPU compatibility for GLSL runtime shaders.
/// If fragment shaders are unsupported or fail to compile on the device GPU,
/// automatically and gracefully routes rendering to pure Canvas 3D visualizers
/// to guarantee the app NEVER goes black.
class ShaderCapabilityService {
  ShaderCapabilityService._internal();
  static final ShaderCapabilityService instance = ShaderCapabilityService._internal();

  bool _areShadersSupported = true;
  bool _checked = false;
  String? _lastError;

  bool get areShadersSupported => _areShadersSupported;
  bool get hasBeenChecked => _checked;
  String? get lastError => _lastError;

  Future<bool> checkShaderSupport() async {
    if (_checked) return _areShadersSupported;

    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/orb_visualizer.frag');
      final shader = program.fragmentShader();
      // Set test uniforms
      shader.setFloat(0, 100.0);
      shader.setFloat(1, 100.0);
      _areShadersSupported = true;
      _lastError = null;
    } catch (e) {
      _areShadersSupported = false;
      _lastError = e.toString();
      debugPrint("ShaderCapabilityService: GPU shaders not supported ($e). Safely using pure Canvas visualizer engine.");
    } finally {
      _checked = true;
    }

    return _areShadersSupported;
  }

  void forceCanvasFallback() {
    _areShadersSupported = false;
  }
}
