import 'dart:io';
import 'package:flutter/services.dart';

/// Service that dynamically resolves configuration and API secrets.
///
/// Supports:
/// 1. Compile-time defines via `--dart-define-from-file=.env` or `--dart-define=KEY=VAL`
/// 2. Runtime `.env` file parsing from root directory (Desktop / Debug)
/// 3. Bundled `.env` asset loading (Mobile)
/// 4. System environment variables (`Platform.environment`)
class EnvService {
  static final Map<String, String> _env = {};
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Try reading from root filesystem .env (Desktop / Local dev)
    try {
      final file = File('.env');
      if (await file.exists()) {
        final lines = await file.readAsLines();
        _parseLines(lines);
        return;
      }
    } catch (_) {}

    // 2. Try reading from rootBundle asset if bundled
    try {
      final content = await rootBundle.loadString('.env');
      _parseLines(content.split('\n'));
      return;
    } catch (_) {}

    try {
      final content = await rootBundle.loadString('assets/.env');
      _parseLines(content.split('\n'));
      return;
    } catch (_) {}
  }

  static void _parseLines(List<String> lines) {
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eqIdx = line.indexOf('=');
      if (eqIdx != -1) {
        final key = line.substring(0, eqIdx).trim();
        var val = line.substring(eqIdx + 1).trim();
        // Strip surrounding quotes if present
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
        _env[key] = val;
      }
    }
  }

  static String get(String key, {String defaultValue = ''}) {
    if (_env.containsKey(key) && _env[key]!.isNotEmpty) {
      return _env[key]!;
    }
    // Fallback to Platform.environment
    try {
      final platVal = Platform.environment[key];
      if (platVal != null && platVal.isNotEmpty) return platVal;
    } catch (_) {}

    return defaultValue;
  }

  // Trakt Credentials (checks compile-time dart-define first, then runtime .env)
  static String get traktClientId {
    const compileVal = String.fromEnvironment('TRAKT_CLIENT_ID');
    if (compileVal.isNotEmpty) return compileVal;
    return get('TRAKT_CLIENT_ID');
  }

  static String get traktClientSecret {
    const compileVal = String.fromEnvironment('TRAKT_CLIENT_SECRET');
    if (compileVal.isNotEmpty) return compileVal;
    return get('TRAKT_CLIENT_SECRET');
  }

  // Simkl Credentials (checks compile-time dart-define first, then runtime .env)
  static String get simklClientId {
    const compileVal = String.fromEnvironment('SIMKL_CLIENT_ID');
    if (compileVal.isNotEmpty) return compileVal;
    return get('SIMKL_CLIENT_ID');
  }

  static String get simklClientSecret {
    const compileVal = String.fromEnvironment('SIMKL_CLIENT_SECRET');
    if (compileVal.isNotEmpty) return compileVal;
    return get('SIMKL_CLIENT_SECRET');
  }

  // Discord Rich Presence App ID (checks compile-time dart-define first, then runtime .env)
  static String get discordAppId {
    const compileVal = String.fromEnvironment('DISCORD_APP_ID');
    if (compileVal.isNotEmpty) return compileVal;
    return get('DISCORD_APP_ID');
  }

  // TMDb API key (checks compile-time dart-define first, then runtime .env)
  static String get tmdbApiKey {
    const compileVal = String.fromEnvironment('TMDB_API_KEY');
    if (compileVal.isNotEmpty) return compileVal;
    return get('TMDB_API_KEY');
  }
}
