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

  // Simkl app name sent to the Simkl API (checks compile-time dart-define first, then runtime .env)
  static String get simklAppName {
    const compileVal = String.fromEnvironment('SIMKL_APP_NAME');
    if (compileVal.isNotEmpty) return compileVal;
    return get('SIMKL_APP_NAME', defaultValue: 'ZPlay');
  }

  // AllDebrid agent identifier (checks compile-time dart-define first, then runtime .env)
  static String get alldebridAgent {
    const compileVal = String.fromEnvironment('ALLDEBRID_AGENT');
    if (compileVal.isNotEmpty) return compileVal;
    return get('ALLDEBRID_AGENT', defaultValue: 'ZPlay');
  }

  // Upstream scraper hosts (checks compile-time dart-define first, then runtime .env).
  // Empty means "not configured": the caller keeps its built-in default host.
  static String get tmdbProxyBase {
    const compileVal = String.fromEnvironment('TMDB_PROXY_BASE');
    if (compileVal.isNotEmpty) return compileVal;
    return get('TMDB_PROXY_BASE');
  }

  static String get videasyApiBase {
    const compileVal = String.fromEnvironment('VIDEASY_API_BASE');
    if (compileVal.isNotEmpty) return compileVal;
    return get('VIDEASY_API_BASE');
  }

  // Wyzie subtitle key (checks compile-time dart-define first, then runtime .env)
  static String get wyzieApiKey {
    const compileVal = String.fromEnvironment('WYZIE_API_KEY');
    if (compileVal.isNotEmpty) return compileVal;
    return get('WYZIE_API_KEY');
  }

  // Audionest search key (checks compile-time dart-define first, then runtime .env)
  static String get audiobookSearchKey {
    const compileVal = String.fromEnvironment('AUDIOBOOK_SEARCH_KEY');
    if (compileVal.isNotEmpty) return compileVal;
    return get('AUDIOBOOK_SEARCH_KEY');
  }

  // Audionest service bearer (checks compile-time dart-define first, then runtime .env)
  static String get audiobookServiceKey {
    const compileVal = String.fromEnvironment('AUDIOBOOK_SERVICE_KEY');
    if (compileVal.isNotEmpty) return compileVal;
    return get('AUDIOBOOK_SERVICE_KEY');
  }

  // Paper2Audio key (checks compile-time dart-define first, then runtime .env)
  static String get paper2audioKey {
    const compileVal = String.fromEnvironment('PAPER2AUDIO_KEY');
    if (compileVal.isNotEmpty) return compileVal;
    return get('PAPER2AUDIO_KEY');
  }

  // VidGod cache bearer (checks compile-time dart-define first, then runtime .env)
  static String get vidgodToken {
    const compileVal = String.fromEnvironment('VIDGOD_TOKEN');
    if (compileVal.isNotEmpty) return compileVal;
    return get('VIDGOD_TOKEN');
  }

  // Films365 downloader bearer (checks compile-time dart-define first, then runtime .env)
  static String get xdownloaderToken {
    const compileVal = String.fromEnvironment('XDOWNLOADER_TOKEN');
    if (compileVal.isNotEmpty) return compileVal;
    return get('XDOWNLOADER_TOKEN');
  }
}
