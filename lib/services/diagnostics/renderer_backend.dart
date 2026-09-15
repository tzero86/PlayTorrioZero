import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent Windows graphics-backend choice (Skia vs Impeller).
///
/// Measured A/B on this machine: Skia felt faster, and the Impeller run
/// coincided with an NVIDIA driver crash notice alongside the engine log
/// `embedder_surface_gl_impeller.cc(126) Using Impeller OpenGLESSDF`,
/// while the Skia run showed no such line. Impeller-on-NVIDIA is therefore
/// treated as crash-correlated: Windows defaults to Skia.
///
/// The saved value is read natively by `windows/runner/main.cpp` *before*
/// the engine starts (the release exe bakes the platform default, Impeller,
/// so a Dart-side switch alone cannot affect the shipped build) via
/// `DartProject::set_impeller_switch` — see
/// `flutter/engine/src/flutter/shell/platform/windows/client_wrapper/include/flutter/dart_project.h:147-150`.
/// The Dart copy here only drives the Settings UI and the startup log line.
enum RendererBackend {
  /// Skia rasterizer (`--enable-impeller=false` is forwarded to the engine).
  skia(
    'skia',
    'Skia',
    'Recommended on Windows — faster in practice here and avoids the NVIDIA driver crash seen with Impeller.',
  ),

  /// Impeller renderer (the engine default).
  impeller(
    'impeller',
    'Impeller',
    'Engine default — kept selectable for testing. Coincided with an NVIDIA driver crash notice on this machine.',
  );

  const RendererBackend(this.storageValue, this.label, this.description);

  /// Value stored in SharedPreferences (key `renderer_backend`, prefixed
  /// `flutter.` on disk by the plugin).
  final String storageValue;
  final String label;
  final String description;

  static RendererBackend fromStorage(String? value) {
    for (final backend in RendererBackend.values) {
      if (backend.storageValue == value) return backend;
    }
    return Platform.isWindows
        ? RendererBackend.skia
        : RendererBackend.impeller;
  }
}

abstract final class RendererBackendSettings {
  static const _keyBackend = 'renderer_backend';

  static final ValueNotifier<RendererBackend> current =
      ValueNotifier<RendererBackend>(
        Platform.isWindows
            ? RendererBackend.skia
            : RendererBackend.impeller,
      );

  static bool get useImpeller => current.value == RendererBackend.impeller;

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      current.value = RendererBackend.fromStorage(
        prefs.getString(_keyBackend),
      );
    } catch (e) {
      debugPrint('[RendererBackendSettings] Error initializing: $e');
    }
    debugPrint('[Renderer] backend=${current.value.storageValue}');
  }

  static Future<void> setBackend(RendererBackend backend) async {
    current.value = backend;
    debugPrint(
      '[Renderer] backend=${backend.storageValue} (restart app to apply)',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyBackend, backend.storageValue);
    } catch (e) {
      debugPrint('[RendererBackendSettings] Error saving backend: $e');
    }
  }
}
