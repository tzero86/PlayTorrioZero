import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../services/addon/addon_manager.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
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

/// Third-party brand hues. These identify an external service, so they stay
/// outside the palette-derived token layer.
const Color _traktBrand = Color(0xFFED1C24);
const Color _simklBrand = Color(0xFF00ADFF);
const Color _discordBrand = Color(0xFF5865F2);

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
        final tokens = ctx.tokens;
        return Dialog(
          backgroundColor: tokens.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: ZplayRadius.lgAll,
            side: tokens.hairlineStrong,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(ZplaySpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: tokens.success.withValues(
                            alpha: ZplayOpacity.overlayHover,
                          ),
                          borderRadius: ZplayRadius.smAll,
                        ),
                        child: Icon(
                          Icons.backup_rounded,
                          color: tokens.success,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Backup & Restore',
                              style: ZplayType.title.toStyle(
                                color: tokens.textPrimary,
                              ),
                            ),
                            Text(
                              'Cross-device JSON configuration',
                              style: ZplayType.bodySmall.toStyle(
                                color: tokens.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Export your configuration (installed addons, IPTV portals, Debrid keys & themes) to JSON or import on another device.',
                    style: ZplayType.body.toStyle(color: tokens.textEmphasis),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: tokens.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: ZplayRadius.smAll,
                            ),
                          ),
                          icon: const Icon(
                            Icons.file_upload_outlined,
                            size: 18,
                          ),
                          label: Text(
                            'Export JSON',
                            style: ZplayType.label.toStyle(),
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
                                SnackBar(
                                  content: const Text(
                                    'Configuration JSON copied to clipboard! Save or paste it on any device.',
                                  ),
                                  backgroundColor: tokens.success,
                                  duration: const Duration(seconds: 4),
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
                            foregroundColor: tokens.textPrimary,
                            side: BorderSide(color: tokens.borderStrong),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const RoundedRectangleBorder(
                              borderRadius: ZplayRadius.smAll,
                            ),
                          ),
                          icon: const Icon(
                            Icons.file_download_outlined,
                            size: 18,
                          ),
                          label: Text(
                            'Import JSON',
                            style: ZplayType.label.toStyle(),
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
        final tokens = ctx.tokens;
        return Dialog(
          backgroundColor: tokens.surfaceOverlay,
          shape: RoundedRectangleBorder(
            borderRadius: ZplayRadius.lgAll,
            side: tokens.hairlineStrong,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(ZplaySpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        color: tokens.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Paste Configuration JSON',
                        style: ZplayType.title.toStyle(
                          color: tokens.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textController,
                    maxLines: 8,
                    style: ZplayType.bodySmall
                        .toStyle(color: tokens.textPrimary)
                        .copyWith(fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: 'Paste backup JSON here...',
                      hintStyle: ZplayType.bodySmall.toStyle(
                        color: tokens.textDisabled,
                      ),
                      filled: true,
                      fillColor: tokens.surface,
                      border: OutlineInputBorder(
                        borderRadius: ZplayRadius.smAll,
                        borderSide: BorderSide(color: tokens.borderDefault),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton.icon(
                        icon: Icon(
                          Icons.paste_rounded,
                          size: 16,
                          color: tokens.accent,
                        ),
                        label: Text(
                          'Paste from Clipboard',
                          style: ZplayType.label.toStyle(color: tokens.accent),
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
                          backgroundColor: tokens.accent,
                          foregroundColor: tokens.onAccent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: ZplayRadius.smAll,
                          ),
                        ),
                        child: Text(
                          'Restore Now',
                          style: ZplayType.label.toStyle(),
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
                                  backgroundColor: tokens.success,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text('Import Failed: $e'),
                                backgroundColor: tokens.danger,
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
          packageName: 'io.github.tzero86.zplay',
          version: '1.1.6',
          buildNumber: '2019',
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
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        surfaceTintColor: Colors.transparent,
        // The shell family draws this header as an opaque palette band with a
        // bottom hairline rather than a translucent wash over the page.
        shape: Border(bottom: tokens.hairline),
        // No explicit leading: the framework already gates the back button on canPop,
        // so it vanishes in the shell and returns if this page is pushed.
        title: Text(
          'Settings',
          style: ZplayType.titleLarge.toStyle(color: tokens.textPrimary),
        ),
      ),
      body: AnimatedAmbientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                ZplaySpacing.s16,
                ZplaySpacing.s20,
                ZplaySpacing.s16,
                ZplaySpacing.s32 + bottomInset,
              ),
              children: [
                // Header Intro Card
                Container(
                  padding: const EdgeInsets.all(ZplaySpacing.s20),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: ZplayRadius.lgAll,
                    border: Border.fromBorderSide(tokens.hairline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: tokens.accentSubtle,
                          borderRadius: ZplayRadius.mdAll,
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: tokens.accent,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preferences & Configuration',
                              style: ZplayType.subtitle.toStyle(
                                color: tokens.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Manage streaming providers, addons, UI effects, and account sync.',
                              style: ZplayType.bodySmall.toStyle(
                                color: tokens.textSecondary,
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
                  style: ZplayType.overline.toStyle(color: tokens.textMuted),
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
                          iconColor: tokens.accent,
                          title: 'Appearance & Interface',
                          subtitle:
                              'Liquid Glass setup, color themes, and Home Page UI',
                          badgeText: glassEnabled
                              ? '${currentPalette.name} · Glass ON'
                              : currentPalette.name,
                          badgeColor: tokens.accent,
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
                      iconColor: tokens.accent,
                      title: 'Video & Upscaling',
                      subtitle:
                          'Anime4K neural GLSL shader presets and GPU pipeline',
                      badgeText: anime4kPreset == Anime4KPreset.off
                          ? 'Off'
                          : anime4kPreset.label.split('(').first.trim(),
                      badgeColor: anime4kPreset == Anime4KPreset.off
                          ? tokens.textMuted
                          : tokens.accent,
                      onTap: () => _navigateTo(const VideoSettingsPage()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 3. Debrid & Cloud Streaming
                _SettingsCategoryTile(
                  icon: Icons.cloud_download_rounded,
                  iconColor: tokens.accent,
                  title: 'Debrid & Cloud Streaming',
                  subtitle:
                      'Real-Debrid, TorBox, AllDebrid, Premiumize & Debrid-Link',
                  badgeText: _useDebrid
                      ? (_debridProvider != 'None' ? _debridProvider : 'Active')
                      : 'Disabled',
                  badgeColor: _useDebrid ? tokens.accent : tokens.textMuted,
                  onTap: () => _navigateTo(const DebridSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 3. Metadata & Catalogs (Addons)
                _SettingsCategoryTile(
                  icon: Icons.extension_rounded,
                  iconColor: tokens.accent,
                  title: 'Addons',
                  subtitle: 'Stremio catalogs and content providers',
                  badgeText: '$addonCount Installed',
                  badgeColor: tokens.accent,
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
                      iconColor: isCustom ? tokens.accent : tokens.success,
                      title: 'Built-in Providers',
                      subtitle:
                          'ZPlayHTTP streaming sources, priority order & toggles',
                      badgeText: isCustom ? 'Custom' : 'Default',
                      badgeColor: isCustom ? tokens.accent : tokens.success,
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
                      iconColor: isP2p ? tokens.warning : tokens.textSecondary,
                      title: 'Built-in P2P Torrent Source',
                      subtitle: isP2p
                          ? 'ZPlay torrent swarms (Knaben, TorrentGalaxy) active'
                          : 'P2P disabled. Using only direct HTTP streaming (ZPlayHTTP)',
                      badgeText: isP2p ? 'P2P Active' : 'HTTP Only',
                      badgeColor: isP2p ? tokens.warning : tokens.success,
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
                          ? tokens.info
                          : tokens.textSecondary,
                      title: 'TV Airing Calendar',
                      subtitle: isCalEnabled
                          ? 'Calendar buttons active on Home top bar and section headers'
                          : 'Calendar disabled and hidden across all pages',
                      badgeText: isCalEnabled ? 'Enabled' : 'Disabled',
                      badgeColor: isCalEnabled ? tokens.info : tokens.textMuted,
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
                          ? tokens.accent
                          : tokens.textSecondary,
                      title: 'AI Recommendation Quiz',
                      subtitle: isAiEnabled
                          ? 'AI Taste Profile Quiz active on Home and Search bars'
                          : 'AI quiz disabled and hidden across all pages',
                      badgeText: isAiEnabled ? 'Enabled' : 'Disabled',
                      badgeColor: isAiEnabled
                          ? tokens.accent
                          : tokens.textMuted,
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
                          ? tokens.danger
                          : tokens.textSecondary,
                      title: 'Adult Content',
                      subtitle: isAdultOn
                          ? '18+ catalogs, search results and sources are enabled'
                          : 'Hidden. No 18+ catalogs, search results or sources are fetched',
                      badgeText: isAdultOn ? 'On' : 'Off',
                      badgeColor: isAdultOn ? tokens.danger : tokens.textMuted,
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
                            ? _discordBrand
                            : tokens.textSecondary,
                        title: 'Discord Rich Presence',
                        subtitle: isDiscordEnabled
                            ? 'Broadcasting movies, shows, music & live activity to Discord'
                            : 'Disabled. Activity is hidden from Discord',
                        badgeText: isDiscordEnabled ? 'Active' : 'Disabled',
                        badgeColor: isDiscordEnabled
                            ? _discordBrand
                            : tokens.textMuted,
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
                  iconColor: _traktBrand,
                  title: 'Trakt.tv Sync',
                  subtitle:
                      'Cross-device watchlist, history & playback synchronization',
                  badgeText: _traktConnected ? 'Connected' : 'Offline',
                  badgeColor: _traktConnected ? _traktBrand : tokens.textMuted,
                  onTap: () => _navigateTo(const TraktSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 6. Simkl Sync
                _SettingsCategoryTile(
                  icon: Icons.tv_rounded,
                  iconColor: _simklBrand,
                  title: 'Simkl Sync',
                  subtitle: 'Cross-device Movies, TV & Anime synchronization',
                  badgeText: _simklConnected ? 'Connected' : 'Offline',
                  badgeColor: _simklConnected ? _simklBrand : tokens.textMuted,
                  onTap: () => _navigateTo(const SimklSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 7. Backup & Restore (JSON)
                _SettingsCategoryTile(
                  icon: Icons.backup_rounded,
                  iconColor: tokens.accent,
                  title: 'Backup & Restore',
                  subtitle:
                      'Export or import your settings, addons & IPTV portals (JSON)',
                  badgeText: 'JSON',
                  badgeColor: tokens.accent,
                  onTap: _showBackupRestoreDialog,
                ),

                const SizedBox(height: 12),

                // 8. App Updates & System
                _SettingsCategoryTile(
                  icon: Icons.system_update_rounded,
                  iconColor: tokens.accent,
                  title: 'App Updates',
                  subtitle: 'Check for latest software versions and patches',
                  badgeText: _appVersion != null ? 'v$_appVersion' : 'Check',
                  badgeColor: tokens.accent,
                  onTap: () => _navigateTo(const UpdatesSettingsPage()),
                ),

                const SizedBox(height: 12),

                // 9. About ZPlay
                _SettingsCategoryTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: tokens.textEmphasis,
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
    final tokens = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: ZplayRadius.mdAll,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: ZplayRadius.mdAll,
            border: Border.fromBorderSide(tokens.hairline),
          ),
          child: Row(
            children: [
              // Icon Container with subtle tinted background
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: ZplayOpacity.borderStrong),
                  borderRadius: ZplayRadius.smAll,
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
                            style: ZplayType.subtitle.toStyle(
                              color: tokens.textPrimary,
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
                                alpha: ZplayOpacity.borderStrong,
                              ),
                              borderRadius: ZplayRadius.xsAll,
                            ),
                            child: Text(
                              badgeText!,
                              style: ZplayType.caption.toStyle(
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
                      style: ZplayType.bodySmall.toStyle(
                        color: tokens.textSecondary,
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
                color: tokens.textDisabled,
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
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: ZplayRadius.mdAll,
        border: Border.all(
          color: value ? tokens.borderStrong : tokens.borderDefault,
        ),
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: ZplayOpacity.borderStrong),
              borderRadius: ZplayRadius.smAll,
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
                        style: ZplayType.subtitle.toStyle(
                          color: tokens.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onInfoTap != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: tokens.textSecondary,
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
                            alpha: ZplayOpacity.borderStrong,
                          ),
                          borderRadius: ZplayRadius.xsAll,
                        ),
                        child: Text(
                          badgeText!,
                          style: ZplayType.caption.toStyle(
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
                  style: ZplayType.bodySmall.toStyle(
                    color: tokens.textSecondary,
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
              activeColor: tokens.accent,
              activeTrackColor: tokens.accent.withValues(
                alpha: ZplayOpacity.textMuted,
              ),
              inactiveThumbColor: tokens.textSecondary,
              inactiveTrackColor: Colors.white.withValues(
                alpha: ZplayOpacity.borderMedium,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
