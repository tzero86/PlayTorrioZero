import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/addon/addon_manager.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';

import 'appearance_settings_page.dart';
import 'video_settings_page.dart';
import 'debrid_settings_page.dart';
import 'addons_settings_page.dart';
import 'builtin_providers_settings_page.dart';
import 'trakt_settings_page.dart';
import 'simkl_settings_page.dart';
import 'updates_settings_page.dart';
import 'about_settings_page.dart';
import '../../services/player/player_settings.dart';
import '../../services/p2p/p2p_settings_service.dart';
import '../../services/scraper/builtin_providers_settings_service.dart';
import '../../widgets/p2p/p2p_warning_dialog.dart';
import '../../services/discord/discord_rpc_service.dart';
import '../../services/backup/backup_restore_service.dart';
import '../../services/home/home_page_settings.dart';
import '../../services/content/content_settings.dart';

import '../../widgets/common/animated_ambient_background.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _debrid = DebridService();
  bool _useDebrid = false;
  String _debridProvider = 'None';
  String? _appVersion;
  bool _traktConnected = false;
  bool _simklConnected = false;

  void _showBackupRestoreDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF12151E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF10B981,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.backup_rounded,
                          color: Color(0xFF10B981),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backup & Restore',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Cross-device JSON configuration',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Export your configuration (installed addons, IPTV portals, Debrid keys & themes) to JSON or import on another device.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Export JSON',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () async {
                            final jsonStr =
                                await BackupRestoreService.exportSettingsJson();
                            await Clipboard.setData(
                              ClipboardData(text: jsonStr),
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Configuration JSON copied to clipboard! Save or paste it on any device.',
                                  ),
                                  backgroundColor: Color(0xFF10B981),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.file_download_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            'Import JSON',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showImportJsonInputDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImportJsonInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF12151E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.file_download_outlined,
                        color: Color(0xFF00E5FF),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Paste Configuration JSON',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white54,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Paste backup JSON here...',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0A0C12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: const Icon(
                          Icons.paste_rounded,
                          size: 16,
                          color: Color(0xFF00E5FF),
                        ),
                        label: const Text(
                          'Paste from Clipboard',
                          style: TextStyle(color: Color(0xFF00E5FF)),
                        ),
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (data?.text != null) {
                            textController.text = data!.text!;
                          }
                        },
                      ),
                      const Spacer(),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Restore Now',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final txt = textController.text.trim();
                          if (txt.isEmpty) return;
                          try {
                            final msg =
                                await BackupRestoreService.importSettingsJson(
                                  txt,
                                );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            if (mounted) {
                              _loadOverviewState();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(msg),
                                  backgroundColor: const Color(0xFF10B981),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Import Failed: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    BuiltinProvidersSettingsService.instance.init();
    _loadOverviewState();
  }

  Future<void> _loadOverviewState() async {
    final useDebrid = await _debrid.getUseDebridForStreams();
    final provider = await _debrid.getSelectedService();
    final traktAuth = await TraktService.instance.isAuthenticated();
    final simklAuth = await SimklService.instance.isAuthenticated();
    final pkg = await PackageInfo.fromPlatform().catchError((_) => PackageInfo(
          appName: 'ZPlay',
          packageName: 'com.example.zplay',
          version: '1.1.6',
          buildNumber: '17',
        ));

    if (mounted) {
      setState(() {
        _useDebrid = useDebrid;
        _debridProvider = provider;
        _appVersion = pkg.version;
        _traktConnected = traktAuth;
        _simklConnected = simklAuth;
      });
    }
  }

  Future<void> _navigateTo(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    // Refresh badges when returning
    _loadOverviewState();
  }

  @override
  Widget build(BuildContext context) {
    final addonCount = AddonManager.instance.addons.length;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017).withValues(alpha: 0.85),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: AnimatedAmbientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 32 + bottomInset),
              children: [
                // Header Intro Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7C5CFF).withValues(alpha: 0.12),
                        const Color(0xFF00E5FF).withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(
                        0xFF7C5CFF,
                      ).withValues(alpha: 20 / 100),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF7C5CFF,
                          ).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Color(0xFF7C5CFF),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Preferences & Configuration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Manage streaming providers, addons, UI effects, and account sync.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.white.withValues(alpha: 0.5),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section Label
                Text(
                  'CATEGORIES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),

                // 1. Appearance & Interface
                ValueListenableBuilder<bool>(
                  valueListenable: GlassSettings.enabled,
                  builder: (context, glassEnabled, _) {
                    return ValueListenableBuilder<AppThemePalette>(
                      valueListenable: AppThemeService.currentPalette,
                      builder: (context, currentPalette, _) {
                        return _SettingsCategoryTile(
                          icon: Icons.palette_rounded,
                          iconColor: currentPalette.primaryColor,
                          title: 'Appearance & Interface',
                          subtitle:
                              'Liquid Glass setup, color themes, and Home Page UI',
                          badgeText: glassEnabled
                              ? '${currentPalette.name} · Glass ON'
                              : currentPalette.name,
                          badgeColor: currentPalette.primaryColor,
                          onTap: () =>
                              _navigateTo(const AppearanceSettingsPage()),
                        );
                      },
                    );
                  },
                ),
                // 2. Video & Anime4K Upscaling
                ValueListenableBuilder<Anime4KPreset>(
                  valueListenable: PlayerSettings.anime4kPreset,
                  builder: (context, anime4kPreset, _) {
                    return _SettingsCategoryTile(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: const Color(0xFF7C5CFF),
                      title: 'Video & Upscaling',
                      subtitle:
                          'Anime4K neural GLSL shader presets and GPU pipeline',
                      badgeText: anime4kPreset == Anime4KPreset.off
                          ? 'Off'
                          : anime4kPreset.label.split('(').first.trim(),
                      badgeColor: anime4kPreset == Anime4KPreset.off
                          ? Colors.white38
                          : const Color(0xFF7C5CFF),
                      onTap: () => _navigateTo(const VideoSettingsPage()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 3. Debrid & Cloud Streaming
                _SettingsCategoryTile(
                  icon: Icons.cloud_download_rounded,
                  iconColor: const Color(0xFF00E5FF),
                  title: 'Debrid & Cloud Streaming',
                  subtitle:
                      'Real-Debrid, TorBox, AllDebrid, Premiumize & Debrid-Link',
                  badgeText: _useDebrid
                      ? (_debridProvider != 'None' ? _debridProvider : 'Active')
                      : 'Disabled',
                  badgeColor: _useDebrid
                      ? const Color(0xFF00E5FF)
                      : Colors.white38,
                  onTap: () => _navigateTo(const DebridSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 3. Metadata & Catalogs (Addons)
                _SettingsCategoryTile(
                  icon: Icons.extension_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Addons',
                  subtitle: 'Stremio catalogs and content providers',
                  badgeText: '$addonCount Installed',
                  badgeColor: const Color(0xFF10B981),
                  onTap: () => _navigateTo(const AddonsSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 4. Built-in Providers (ZPlayHTTP)
                ListenableBuilder(
                  listenable: BuiltinProvidersSettingsService.instance,
                  builder: (context, _) {
                    final isCustom =
                        BuiltinProvidersSettingsService.instance.isCustom;
                    return _SettingsCategoryTile(
                      icon: Icons.dns_rounded,
                      iconColor: isCustom
                          ? const Color(0xFF7C5CFF)
                          : const Color(0xFF10B981),
                      title: 'Built-in Providers',
                      subtitle:
                          'ZPlayHTTP streaming sources, priority order & toggles',
                      badgeText: isCustom ? 'Custom' : 'Default',
                      badgeColor: isCustom
                          ? const Color(0xFF7C5CFF)
                          : const Color(0xFF10B981),
                      onTap: () =>
                          _navigateTo(const BuiltinProvidersSettingsPage()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 4. Built-in P2P Torrent Source Toggle (ZPlay)
                ValueListenableBuilder<bool>(
                  valueListenable: P2pSettingsService.isP2pEnabled,
                  builder: (context, isP2p, _) {
                    return _SettingsSwitchTile(
                      icon: Icons.hub_rounded,
                      iconColor: isP2p
                          ? const Color(0xFFF59E0B)
                          : Colors.white54,
                      title: 'Built-in P2P Torrent Source',
                      subtitle: isP2p
                          ? 'ZPlay torrent swarms (Knaben, TorrentGalaxy) active'
                          : 'P2P disabled. Using only direct HTTP streaming (ZPlayHTTP)',
                      badgeText: isP2p ? 'P2P Active' : 'HTTP Only',
                      badgeColor: isP2p
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF10B981),
                      value: isP2p,
                      onChanged: (val) async {
                        await P2pSettingsService.setP2pEnabled(val);
                      },
                      onInfoTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => const P2pWarningDialog(),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 5. TV Airing Calendar Toggle
                ValueListenableBuilder<bool>(
                  valueListenable: HomePageSettings.enableCalendar,
                  builder: (context, isCalEnabled, _) {
                    return _SettingsSwitchTile(
                      icon: Icons.calendar_month_rounded,
                      iconColor: isCalEnabled
                          ? const Color(0xFF38BDF8)
                          : Colors.white54,
                      title: 'TV Airing Calendar',
                      subtitle: isCalEnabled
                          ? 'Calendar buttons active on Home top bar and section headers'
                          : 'Calendar disabled and hidden across all pages',
                      badgeText: isCalEnabled ? 'Enabled' : 'Disabled',
                      badgeColor: isCalEnabled
                          ? const Color(0xFF38BDF8)
                          : Colors.white38,
                      value: isCalEnabled,
                      onChanged: (val) async {
                        await HomePageSettings.setEnableCalendar(val);
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 6. AI Recommendation Quiz Toggle
                ValueListenableBuilder<bool>(
                  valueListenable: HomePageSettings.enableAiQuiz,
                  builder: (context, isAiEnabled, _) {
                    return _SettingsSwitchTile(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: isAiEnabled
                          ? const Color(0xFFF472B6)
                          : Colors.white54,
                      title: 'AI Recommendation Quiz',
                      subtitle: isAiEnabled
                          ? 'AI Taste Profile Quiz active on Home and Search bars'
                          : 'AI quiz disabled and hidden across all pages',
                      badgeText: isAiEnabled ? 'Enabled' : 'Disabled',
                      badgeColor: isAiEnabled
                          ? const Color(0xFFF472B6)
                          : Colors.white38,
                      value: isAiEnabled,
                      onChanged: (val) async {
                        await HomePageSettings.setEnableAiQuiz(val);
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 6. Adult Content (18+) Global Switch
                ValueListenableBuilder<bool>(
                  valueListenable: ContentSettings.adultEnabled,
                  builder: (context, isAdultOn, _) {
                    return _SettingsSwitchTile(
                      icon: Icons.eighteen_up_rating_rounded,
                      iconColor: isAdultOn
                          ? const Color(0xFFEF4444)
                          : Colors.white54,
                      title: 'Adult Content',
                      subtitle: isAdultOn
                          ? '18+ catalogs, search results and sources are enabled'
                          : 'Hidden. No 18+ catalogs, search results or sources are fetched',
                      badgeText: isAdultOn ? 'On' : 'Off',
                      badgeColor: isAdultOn
                          ? const Color(0xFFEF4444)
                          : Colors.white38,
                      value: isAdultOn,
                      onChanged: (val) async {
                        await ContentSettings.setAdultEnabled(val);
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 5. Discord Rich Presence (Desktop Only)
                if (Platform.isWindows ||
                    Platform.isLinux ||
                    Platform.isMacOS) ...[
                  ValueListenableBuilder<bool>(
                    valueListenable: DiscordRpcService.instance.isEnabled,
                    builder: (context, isDiscordEnabled, _) {
                      return _SettingsSwitchTile(
                        icon: Icons.sports_esports_rounded,
                        iconColor: isDiscordEnabled
                            ? const Color(0xFF5865F2)
                            : Colors.white54,
                        title: 'Discord Rich Presence',
                        subtitle: isDiscordEnabled
                            ? 'Broadcasting movies, shows, music & live activity to Discord'
                            : 'Disabled. Activity is hidden from Discord',
                        badgeText: isDiscordEnabled ? 'Active' : 'Disabled',
                        badgeColor: isDiscordEnabled
                            ? const Color(0xFF5865F2)
                            : Colors.white38,
                        value: isDiscordEnabled,
                        onChanged: (val) async {
                          await DiscordRpcService.instance.setEnabled(val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                // 6. Trakt Sync
                _SettingsCategoryTile(
                  icon: Icons.movie_filter_rounded,
                  iconColor: const Color(0xFFED1C24),
                  title: 'Trakt.tv Sync',
                  subtitle:
                      'Cross-device watchlist, history & playback synchronization',
                  badgeText: _traktConnected ? 'Connected' : 'Offline',
                  badgeColor: _traktConnected
                      ? const Color(0xFFED1C24)
                      : Colors.white38,
                  onTap: () => _navigateTo(const TraktSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 6. Simkl Sync
                _SettingsCategoryTile(
                  icon: Icons.tv_rounded,
                  iconColor: const Color(0xFF00ADFF),
                  title: 'Simkl Sync',
                  subtitle: 'Cross-device Movies, TV & Anime synchronization',
                  badgeText: _simklConnected ? 'Connected' : 'Offline',
                  badgeColor: _simklConnected
                      ? const Color(0xFF00ADFF)
                      : Colors.white38,
                  onTap: () => _navigateTo(const SimklSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 7. Backup & Restore (JSON)
                _SettingsCategoryTile(
                  icon: Icons.backup_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Backup & Restore',
                  subtitle:
                      'Export or import your settings, addons & IPTV portals (JSON)',
                  badgeText: 'JSON',
                  badgeColor: const Color(0xFF10B981),
                  onTap: _showBackupRestoreDialog,
                ),

                const SizedBox(height: 12),

                // 8. App Updates & System
                _SettingsCategoryTile(
                  icon: Icons.system_update_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'App Updates',
                  subtitle: 'Check for latest software versions and patches',
                  badgeText: _appVersion != null ? 'v$_appVersion' : 'Check',
                  badgeColor: const Color(0xFFF59E0B),
                  onTap: () => _navigateTo(const UpdatesSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 9. About ZPlay
                _SettingsCategoryTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.white70,
                  title: 'About ZPlay',
                  subtitle: 'Architecture, video engine, and credits',
                  onTap: () => _navigateTo(const AboutSettingsPage()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Category Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCategoryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              // Icon Container with subtle tinted background
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Title and Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? iconColor).withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: badgeColor ?? iconColor,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.45),
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Chevron right
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Switch Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onInfoTap;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.value,
    required this.onChanged,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? iconColor.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),

          // Title and Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onInfoTap != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Colors.white54,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'P2P Advisory Details',
                        onPressed: onInfoTap,
                      ),
                    ],
                    if (badgeText != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? iconColor).withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText!,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: badgeColor ?? iconColor,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Switch
          Transform.scale(
            scale: 0.9,
            child: Switch.adaptive(
              value: value,
              activeColor: const Color(0xFFF59E0B),
              activeTrackColor: const Color(0xFFF59E0B).withValues(alpha: 0.35),
              inactiveThumbColor: Colors.white60,
              inactiveTrackColor: Colors.white10,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
