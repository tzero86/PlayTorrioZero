import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages settings for the built-in P2P (torrent) source (ZPlay)
/// and the startup privacy/ISP advisory modal.
class P2pSettingsService {
  P2pSettingsService._();

  static const String _kP2pEnabledKey = 'zplay_p2p_source_enabled';
  static const String _kNeverShowWarningKey = 'zplay_p2p_warning_never_show';

  /// Whether the built-in P2P torrent source ('ZPlay') is enabled.
  /// When false, only direct HTTP streaming ('ZPlayHTTP') and external addons are used.
  static final ValueNotifier<bool> isP2pEnabled = ValueNotifier<bool>(true);

  /// Initializes the service and loads preferences from disk.
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isP2pEnabled.value = prefs.getBool(_kP2pEnabledKey) ?? true;
    } catch (e) {
      debugPrint('[P2pSettingsService] Error initializing: $e');
    }
  }

  /// Updates the P2P torrent source enabled state and persists it.
  static Future<void> setP2pEnabled(bool enabled) async {
    isP2pEnabled.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kP2pEnabledKey, enabled);
    } catch (e) {
      debugPrint('[P2pSettingsService] Error saving enabled state: $e');
    }
  }

  /// Checks if the startup P2P advisory modal should be displayed.
  static Future<bool> shouldShowWarning() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final neverShow = prefs.getBool(_kNeverShowWarningKey) ?? false;
      return !neverShow;
    } catch (e) {
      debugPrint('[P2pSettingsService] Error checking warning state: $e');
      return true;
    }
  }

  /// Sets whether the startup P2P advisory modal should never be shown again.
  static Future<void> setNeverShowWarning(bool neverShow) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNeverShowWarningKey, neverShow);
    } catch (e) {
      debugPrint('[P2pSettingsService] Error saving never show state: $e');
    }
  }

  /// Resets the warning dialog state so it will show again on next startup.
  static Future<void> resetWarningPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kNeverShowWarningKey);
    } catch (e) {
      debugPrint('[P2pSettingsService] Error resetting warning preference: $e');
    }
  }
}
