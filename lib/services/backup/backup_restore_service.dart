import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../addon/addon_manager.dart';
import '../theme/app_theme_service.dart';
import '../home/home_page_settings.dart';
import '../theme/custom_background_service.dart';
import '../debrid/debrid_service.dart';

class BackupRestoreService {
  static const String appVersion = '1.1.6';

  /// Exports all app settings, installed addons, IPTV portals/playlists,
  /// theme preferences, and credentials into a formatted JSON string.
  static Future<String> exportSettingsJson() async {
    final prefs = await SharedPreferences.getInstance();

    final exportData = <String, dynamic>{
      'version': appVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'platform': defaultTargetPlatform.name,
      'settings': {},
      'theme': {},
      'debrid': {},
      'iptv': {},
      'addons': {},
    };

    // 1. SharedPreferences dump of core settings
    final allKeys = prefs.getKeys();
    final settingsMap = <String, dynamic>{};
    for (final key in allKeys) {
      final val = prefs.get(key);
      if (val is String || val is int || val is double || val is bool || val is List<String>) {
        settingsMap[key] = val;
      }
    }
    exportData['settings'] = settingsMap;

    // 2. Current Theme & Background
    final currentBg = CustomBackgroundService.current;
    exportData['theme'] = {
      'paletteId': AppThemeService.currentPalette.value.id,
      'customBg': {
        'imagePath': currentBg.imagePath,
        'imageUrl': currentBg.imageUrl,
        'opacity': currentBg.opacity,
        'blur': currentBg.blur,
        'blendThemeLights': currentBg.blendThemeLights,
        'themeTintOpacity': currentBg.themeTintOpacity,
      },
      'ambientLightsEnabled': HomePageSettings.enableAmbientLights.value,
      'ambientPattern': HomePageSettings.ambientLightPattern.value.name,
      'ambientIntensity': HomePageSettings.ambientLightIntensity.value,
      'ambientSpeed': HomePageSettings.ambientLightSpeed.value,
    };

    // 3. Debrid configuration
    final debridService = DebridService();
    exportData['debrid'] = {
      'selectedService': await debridService.getSelectedService(),
      'rdKey': prefs.getString('debrid_key_Real-Debrid') ?? '',
      'torboxKey': prefs.getString('debrid_key_TorBox') ?? '',
      'alldebridKey': prefs.getString('debrid_key_AllDebrid') ?? '',
      'premiumizeKey': prefs.getString('debrid_key_Premiumize') ?? '',
      'debridlinkKey': prefs.getString('debrid_key_Debrid-Link') ?? '',
    };

    // 4. IPTV Custom Portals & Playlists
    try {
      final customPortals = prefs.getStringList('iptv_custom_portals') ?? [];
      final m3uPlaylists = prefs.getString('iptv_m3u_playlists') ?? '[]';
      final favPortals = prefs.getStringList('iptv_favorite_portals') ?? [];

      exportData['iptv'] = {
        'customPortals': customPortals,
        'm3uPlaylists': m3uPlaylists,
        'favoritePortals': favPortals,
      };
    } catch (_) {}

    // 5. Installed Addons
    try {
      final installedAddons = AddonManager.instance.addons
          .map((a) => {
                'baseUrl': a.baseUrl,
                'enabled': a.enabled,
                'enableCatalogs': a.enableCatalogs,
                'enableSearch': a.enableSearch,
                'enableStreams': a.enableStreams,
                'enableSubtitles': a.enableSubtitles,
              })
          .toList();

      exportData['addons'] = {
        'installed': installedAddons,
      };
    } catch (_) {}

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// Imports and applies settings from a JSON string.
  /// Returns a status message on success or throws an exception on failure.
  static Future<String> importSettingsJson(String jsonStr) async {
    final dynamic decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid backup format: root must be a JSON object.');
    }

    final prefs = await SharedPreferences.getInstance();
    int restoredItems = 0;

    // 1. Restore SharedPreferences
    if (decoded.containsKey('settings') && decoded['settings'] is Map) {
      final settings = decoded['settings'] as Map;
      for (final entry in settings.entries) {
        final key = entry.key.toString();
        final dynamic val = entry.value;

        if (val is String) {
          await prefs.setString(key, val);
          restoredItems++;
        } else if (val is int) {
          await prefs.setInt(key, val);
          restoredItems++;
        } else if (val is double) {
          await prefs.setDouble(key, val);
          restoredItems++;
        } else if (val is bool) {
          await prefs.setBool(key, val);
          restoredItems++;
        } else if (val is List) {
          final strList = val.map((e) => e.toString()).toList();
          await prefs.setStringList(key, strList);
          restoredItems++;
        }
      }
    }

    // 2. Restore Theme
    if (decoded.containsKey('theme') && decoded['theme'] is Map) {
      final theme = decoded['theme'] as Map;
      final paletteId = theme['paletteId']?.toString();
      if (paletteId != null) {
        final found = AppThemeService.palettes.firstWhere(
          (p) => p.id == paletteId,
          orElse: () => AppThemeService.palettes.first,
        );
        await AppThemeService.setPalette(found);
      }

      if (theme['customBg'] is Map) {
        final bgMap = Map<String, dynamic>.from(theme['customBg'] as Map);
        if (bgMap['imageUrl'] != null && bgMap['imageUrl'].toString().isNotEmpty) {
          await CustomBackgroundService.setImageUrl(bgMap['imageUrl'].toString());
        }
        if (bgMap['opacity'] is num) {
          await CustomBackgroundService.setOpacity((bgMap['opacity'] as num).toDouble());
        }
        if (bgMap['blur'] is num) {
          await CustomBackgroundService.setBlur((bgMap['blur'] as num).toDouble());
        }
      }
    }

    // 3. Restore Debrid Keys
    if (decoded.containsKey('debrid') && decoded['debrid'] is Map) {
      final debrid = decoded['debrid'] as Map;
      final sel = debrid['selectedService']?.toString();
      if (sel != null && sel.isNotEmpty) {
        await DebridService().saveSelectedService(sel);
      }

      for (final entry in debrid.entries) {
        final k = entry.key.toString();
        final v = entry.value?.toString() ?? '';
        if (v.isNotEmpty) {
          if (k == 'rdKey') await DebridService().realDebrid.saveToken(v);
          if (k == 'torboxKey') await DebridService().torBox.saveKey(v);
          if (k == 'alldebridKey') await DebridService().allDebrid.saveKey(v);
          if (k == 'premiumizeKey') await DebridService().premiumize.saveKey(v);
          if (k == 'debridlinkKey') await DebridService().debridLink.saveKey(v);
        }
      }
    }

    // 4. Restore Addons
    if (decoded.containsKey('addons') && decoded['addons'] is Map) {
      final addonsObj = decoded['addons'] as Map;
      if (addonsObj['installed'] is List) {
        final list = addonsObj['installed'] as List;
        for (final item in list) {
          if (item is Map && item['baseUrl'] != null) {
            final url = item['baseUrl'].toString();
            try {
              final added = await AddonManager.instance.addAddon(url);
              await AddonManager.instance.updateAddonFeature(
                addonId: added.manifest.id,
                enableCatalogs: item['enableCatalogs'] as bool?,
                enableSearch: item['enableSearch'] as bool?,
                enableStreams: item['enableStreams'] as bool?,
                enableSubtitles: item['enableSubtitles'] as bool?,
              );
            } catch (_) {}
          }
        }
      }
    }

    // 5. Restore IPTV
    if (decoded.containsKey('iptv') && decoded['iptv'] is Map) {
      final iptvObj = decoded['iptv'] as Map;
      if (iptvObj['customPortals'] is List) {
        final list = (iptvObj['customPortals'] as List).map((e) => e.toString()).toList();
        await prefs.setStringList('iptv_custom_portals', list);
      }
      if (iptvObj['m3uPlaylists'] is String) {
        await prefs.setString('iptv_m3u_playlists', iptvObj['m3uPlaylists'] as String);
      }
      if (iptvObj['favoritePortals'] is List) {
        final list = (iptvObj['favoritePortals'] as List).map((e) => e.toString()).toList();
        await prefs.setStringList('iptv_favorite_portals', list);
      }
    }

    return 'Successfully restored configuration ($restoredItems settings, addons & portals restored).';
  }
}
