import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomBackgroundPreset {
  final String id;
  final String title;
  final String previewUrl;
  final String fullUrl;

  const CustomBackgroundPreset({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.fullUrl,
  });
}

class CustomBackgroundData {
  final String? imagePath;
  final String? imageUrl;
  final double opacity;
  final double blur;
  final bool blendThemeLights;
  final double themeTintOpacity;

  const CustomBackgroundData({
    this.imagePath,
    this.imageUrl,
    this.opacity = 0.65,
    this.blur = 6.0,
    this.blendThemeLights = true,
    this.themeTintOpacity = 0.35,
  });

  bool get hasCustomBackground =>
      (imagePath != null && imagePath!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  CustomBackgroundData copyWith({
    String? imagePath,
    String? imageUrl,
    bool clearImagePath = false,
    bool clearImageUrl = false,
    double? opacity,
    double? blur,
    bool? blendThemeLights,
    double? themeTintOpacity,
  }) {
    return CustomBackgroundData(
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      opacity: opacity ?? this.opacity,
      blur: blur ?? this.blur,
      blendThemeLights: blendThemeLights ?? this.blendThemeLights,
      themeTintOpacity: themeTintOpacity ?? this.themeTintOpacity,
    );
  }
}

abstract final class CustomBackgroundService {
  static const _keyPath = 'custom_bg_path';
  static const _keyUrl = 'custom_bg_url';
  static const _keyOpacity = 'custom_bg_opacity';
  static const _keyBlur = 'custom_bg_blur';
  static const _keyBlendLights = 'custom_bg_blend_lights';
  static const _keyThemeTint = 'custom_bg_theme_tint';

  static const List<CustomBackgroundPreset> presets = [
    CustomBackgroundPreset(
      id: 'cyber_city',
      title: 'Cyber Neon City',
      previewUrl: 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=400&q=80',
      fullUrl: 'https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=1920&q=90',
    ),
    CustomBackgroundPreset(
      id: 'cosmos_nebula',
      title: 'Cosmic Nebula',
      previewUrl: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=400&q=80',
      fullUrl: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?w=1920&q=90',
    ),
    CustomBackgroundPreset(
      id: 'dark_silk',
      title: 'Dark Liquid Silk',
      previewUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=400&q=80',
      fullUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=1920&q=90',
    ),
    CustomBackgroundPreset(
      id: 'synthwave',
      title: 'Synthwave Horizon',
      previewUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=400&q=80',
      fullUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=1920&q=90',
    ),
    CustomBackgroundPreset(
      id: 'moody_forest',
      title: 'Moody Forest Mist',
      previewUrl: 'https://images.unsplash.com/photo-1506452305024-9d3f02d1c9b5?w=400&q=80&auto=format&fit=crop',
      fullUrl: 'https://images.unsplash.com/photo-1506452305024-9d3f02d1c9b5?w=1920&q=90&auto=format&fit=crop',
    ),
    CustomBackgroundPreset(
      id: 'abstract_geometry',
      title: 'Abstract Dark Neon',
      previewUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=400&q=80',
      fullUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?w=1920&q=90',
    ),
  ];

  static final ValueNotifier<CustomBackgroundData> notifier =
      ValueNotifier<CustomBackgroundData>(const CustomBackgroundData());

  static CustomBackgroundData get current => notifier.value;

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_keyPath);
    final url = prefs.getString(_keyUrl);
    final opacity = prefs.getDouble(_keyOpacity) ?? 0.65;
    final blur = prefs.getDouble(_keyBlur) ?? 6.0;
    final blendLights = prefs.getBool(_keyBlendLights) ?? true;
    final themeTint = prefs.getDouble(_keyThemeTint) ?? 0.35;

    // Verify local file exists if path is provided
    String? validPath;
    if (path != null && path.isNotEmpty) {
      if (File(path).existsSync()) {
        validPath = path;
      }
    }

    notifier.value = CustomBackgroundData(
      imagePath: validPath,
      imageUrl: (validPath == null) ? url : null,
      opacity: opacity.clamp(0.10, 1.0),
      blur: blur.clamp(0.0, 30.0),
      blendThemeLights: blendLights,
      themeTintOpacity: themeTint.clamp(0.0, 0.85),
    );
  }

  static Future<bool> pickAndSetImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );

      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final originalFile = File(result.files.single.path!);
        if (await originalFile.exists()) {
          final appDocDir = await getApplicationDocumentsDirectory();
          final ext = p.extension(originalFile.path);
          final targetPath = p.join(appDocDir.path, 'zplay_custom_background$ext');
          
          await originalFile.copy(targetPath);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyPath, targetPath);
          await prefs.remove(_keyUrl);

          notifier.value = notifier.value.copyWith(
            imagePath: targetPath,
            clearImageUrl: true,
          );
          return true;
        }
      }
    } catch (e) {
      debugPrint('[CustomBackgroundService] pickAndSetImage error: $e');
    }
    return false;
  }

  static Future<void> setImageUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUrl, trimmed);
    await prefs.remove(_keyPath);

    notifier.value = notifier.value.copyWith(
      imageUrl: trimmed,
      clearImagePath: true,
    );
  }

  static Future<void> applyPreset(CustomBackgroundPreset preset) async {
    await setImageUrl(preset.fullUrl);
  }

  static Future<void> clearBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final oldPath = prefs.getString(_keyPath);
    if (oldPath != null) {
      try {
        final f = File(oldPath);
        if (f.existsSync()) await f.delete();
      } catch (_) {}
    }

    await prefs.remove(_keyPath);
    await prefs.remove(_keyUrl);

    notifier.value = notifier.value.copyWith(
      clearImagePath: true,
      clearImageUrl: true,
    );
  }

  static Future<void> setOpacity(double opacity) async {
    final clamped = opacity.clamp(0.10, 1.0);
    notifier.value = notifier.value.copyWith(opacity: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyOpacity, clamped);
  }

  static Future<void> setBlur(double blur) async {
    final clamped = blur.clamp(0.0, 30.0);
    notifier.value = notifier.value.copyWith(blur: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyBlur, clamped);
  }

  static Future<void> setBlendThemeLights(bool blend) async {
    notifier.value = notifier.value.copyWith(blendThemeLights: blend);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBlendLights, blend);
  }

  static Future<void> setThemeTintOpacity(double tint) async {
    final clamped = tint.clamp(0.0, 0.85);
    notifier.value = notifier.value.copyWith(themeTintOpacity: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyThemeTint, clamped);
  }
}
