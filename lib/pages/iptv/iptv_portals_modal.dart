import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/theme/design_tokens.dart';
import '../../services/theme/app_theme_service.dart';
import '../../models/iptv/iptv_models.dart';
import '../../models/iptv/m3u_models.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../services/iptv/iptv_network.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/segmented_tabs.dart';
import 'iptv_portal_browser_page.dart';

class IptvPortalsModal extends StatefulWidget {
  const IptvPortalsModal({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: context.tokens.bg.withValues(alpha: 0.87),
      builder: (_) => const IptvPortalsModal(),
    );
  }

  @override
  State<IptvPortalsModal> createState() => _IptvPortalsModalState();
}

class _IptvPortalsModalState extends State<IptvPortalsModal>
    with SingleTickerProviderStateMixin {
  final _ctrl = IptvController.instance;
  late final TabController _tabController;

  // Add Portal Controllers
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // M3U Controllers
  final _m3uNameCtrl = TextEditingController();
  final _m3uUrlCtrl = TextEditingController();

  bool _showAddForm = false;
  bool _showM3uForm = false;

  bool _isPortalsEditMode = false;
  final Set<String> _selectedPortalKeys = {};

  bool _isM3uEditMode = false;
  final Set<String> _selectedM3uIds = {};

  Offset? _tapPosition;

  String _portalSourceFilter =
      'all'; // 'all', 'custom', 'cloud', 'reddit', 'fav'

  List<VerifiedPortal> get _filteredPortals {
    return _ctrl.verified.where((p) {
      if (_portalSourceFilter == 'fav') return _ctrl.isFavoritePortal(p.key);
      final src = p.portal.source.toLowerCase();
      if (_portalSourceFilter == 'custom') {
        return src.isEmpty || src.contains('custom') || src.contains('manual');
      }
      if (_portalSourceFilter == 'cloud') {
        return src.contains('cloud') || src.contains('vault');
      }
      if (_portalSourceFilter == 'reddit') {
        return src.contains('reddit');
      }
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: IptvSettings.defaultPortalTab.value.clamp(0, 1),
    );
    IptvSettings.changeNotifier.addListener(_onSettingsChanged);
    AppThemeService.currentPalette.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    IptvSettings.changeNotifier.removeListener(_onSettingsChanged);
    AppThemeService.currentPalette.removeListener(_onSettingsChanged);
    _tabController.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _m3uNameCtrl.dispose();
    _m3uUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAddPortal() async {
    final success = await _ctrl.addManual(
      url: _urlCtrl.text,
      username: _userCtrl.text,
      password: _passCtrl.text,
    );
    if (success) {
      _urlCtrl.clear();
      _userCtrl.clear();
      _passCtrl.clear();
      setState(() => _showAddForm = false);
    }
  }

  Future<void> _submitAddM3u() async {
    if (_m3uUrlCtrl.text.trim().isEmpty) return;
    await _ctrl.addM3uFromUrl(_m3uNameCtrl.text, _m3uUrlCtrl.text.trim());
    _m3uNameCtrl.clear();
    _m3uUrlCtrl.clear();
    setState(() => _showM3uForm = false);
  }

  Future<void> _deleteSelectedPortals() async {
    if (_selectedPortalKeys.isEmpty) return;
    final count = _selectedPortalKeys.length;
    final toDelete = Set<String>.from(_selectedPortalKeys);
    setState(() {
      _selectedPortalKeys.clear();
      _isPortalsEditMode = false;
    });
    await _ctrl.deletePortalsByKeys(toDelete);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $count portal${count == 1 ? "" : "s"}'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.tokens.surfaceOverlay,
        ),
      );
    }
  }

  Future<void> _deleteAllPortals() async {
    final count = _ctrl.verified.length;
    setState(() {
      _selectedPortalKeys.clear();
      _isPortalsEditMode = false;
    });
    await _ctrl.deleteAllPortals();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed all $count portals'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.tokens.surfaceOverlay,
        ),
      );
    }
  }

  Future<void> _deleteSelectedM3u() async {
    if (_selectedM3uIds.isEmpty) return;
    final count = _selectedM3uIds.length;
    final toDelete = Set<String>.from(_selectedM3uIds);
    setState(() {
      _selectedM3uIds.clear();
      _isM3uEditMode = false;
    });
    for (final id in toDelete) {
      await _ctrl.deleteM3uPlaylist(id);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $count playlist${count == 1 ? "" : "s"}'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.tokens.surfaceOverlay,
        ),
      );
    }
  }

  Future<void> _deleteAllM3u() async {
    final count = _ctrl.m3uPlaylists.length;
    setState(() {
      _selectedM3uIds.clear();
      _isM3uEditMode = false;
    });
    await _ctrl.deleteAllM3uPlaylists();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed all $count playlists'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.tokens.surfaceOverlay,
        ),
      );
    }
  }

  void _openModalCustomizer(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    final tokens = context.tokens;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 520;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: tokens.surfaceOverlay,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 14 : 32,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: ZplayRadius.lgAll,
            side: BorderSide(color: tokens.borderStrong),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 16 : 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: palette.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Customize Portals Modal',
                        style: ZplayType.title.toStyle(color: tokens.textPrimary),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: tokens.textMuted,
                          size: 20,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: ZplaySpacing.s16),
                  Divider(color: tokens.borderDefault),
                  const SizedBox(height: ZplaySpacing.s12),

                  Text(
                    'Card Display Style',
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: ZplaySpacing.s8),
                  ValueListenableBuilder<PortalCardStyle>(
                    valueListenable: IptvSettings.portalCardStyle,
                    builder: (context, style, _) {
                      return SegmentedTabs<PortalCardStyle>(
                        selected: style,
                        onSelected: (s) {
                          IptvSettings.setPortalCardStyle(s);
                        },
                        options: [
                          for (final s in PortalCardStyle.values)
                            SegmentedTabOption(value: s, label: s.label),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 14),

                  ValueListenableBuilder<bool>(
                    valueListenable: IptvSettings.showPortalExpiry,
                    builder: (context, showExpiry, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Show Portal Expiry Date',
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                        ),
                        value: showExpiry,
                        activeColor: palette.primaryColor,
                        onChanged: (val) =>
                            IptvSettings.setShowPortalExpiry(val),
                      );
                    },
                  ),

                  ValueListenableBuilder<bool>(
                    valueListenable: IptvSettings.showPortalConnections,
                    builder: (context, showConn, _) {
                      return SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Show Max Connections',
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                        ),
                        value: showConn,
                        activeColor: palette.primaryColor,
                        onChanged: (val) =>
                            IptvSettings.setShowPortalConnections(val),
                      );
                    },
                  ),

                  const SizedBox(height: ZplaySpacing.s8),

                  Text(
                    'Default Starting Tab',
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: ZplaySpacing.s8),
                  ValueListenableBuilder<int>(
                    valueListenable: IptvSettings.defaultPortalTab,
                    builder: (context, tabIdx, _) {
                      return SegmentedTabs<int>(
                        selected: tabIdx,
                        onSelected: IptvSettings.setDefaultPortalTab,
                        options: const [
                          SegmentedTabOption(value: 0, label: 'Xtream Panels'),
                          SegmentedTabOption(value: 1, label: 'M3U Playlists'),
                        ],
                      );
                    },
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
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final palette = AppThemeService.currentPalette.value;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final screenWidth = MediaQuery.sizeOf(context).width;
        final screenHeight = MediaQuery.sizeOf(context).height;
        final isMobile = screenWidth < 520;

        return Dialog(
          backgroundColor: tokens.surface,
          insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 28,
            vertical: isMobile ? 14 : 28,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? ZplayRadius.md : ZplayRadius.lg),
            side: BorderSide(color: tokens.borderStrong),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 480 || isMobile;

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 680,
                  maxHeight: isMobile ? screenHeight * 0.94 : 680,
                ),
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        isNarrow ? 12 : 20,
                        isNarrow ? 12 : 18,
                        isNarrow ? 8 : 16,
                        8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(isNarrow ? 6 : 8),
                            decoration: BoxDecoration(
                              color: palette.primaryColor.withValues(
                                alpha: 0.18,
                              ),
                              borderRadius: ZplayRadius.smAll,
                            ),
                            child: Icon(
                              Icons.settings_input_antenna_rounded,
                              color: palette.primaryColor,
                              size: isNarrow ? 18 : 22,
                            ),
                          ),
                          SizedBox(width: isNarrow ? 8 : 12),
                          Expanded(
                            child: Text(
                              isNarrow
                                  ? 'Portals & Playlists'
                                  : 'IPTV Portals & Playlists',
                              style: (isNarrow ? ZplayType.subtitle : ZplayType.title).toStyle(color: tokens.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.tune_rounded,
                              color: tokens.textEmphasis,
                              size: 19,
                            ),
                            tooltip: 'Customize Modal Style',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => _openModalCustomizer(context),
                          ),
                          const SizedBox(width: ZplaySpacing.s4),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: tokens.textMuted,
                              size: 20,
                            ),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // Tab Bar
                    TabBar(
                      controller: _tabController,
                      indicatorColor: palette.primaryColor,
                      indicatorWeight: 3,
                      labelColor: tokens.textPrimary,
                      unselectedLabelColor: tokens.textMuted,
                      labelStyle: (isNarrow ? ZplayType.caption : ZplayType.body).toStyle(),
                      unselectedLabelStyle: (isNarrow ? ZplayType.caption : ZplayType.body).toStyle(),
                      tabs: [
                        Tab(
                          text: isNarrow
                              ? 'Xtream (${_ctrl.verified.length})'
                              : 'Xtream Panels (${_ctrl.verified.length})',
                        ),
                        Tab(
                          text: isNarrow
                              ? 'M3U (${_ctrl.m3uPlaylists.length})'
                              : 'M3U Playlists (${_ctrl.m3uPlaylists.length})',
                        ),
                      ],
                    ),

                    Divider(color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium), height: 1),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPortalsTab(isNarrow),
                          _buildM3uTab(isNarrow),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPortalsTab(bool isMobile) {
    final tokens = context.tokens;
    final palette = AppThemeService.currentPalette.value;
    final currentList = _filteredPortals;
    final allSelected =
        currentList.isNotEmpty &&
        _selectedPortalKeys.length == currentList.length;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Action Buttons Bar
          Wrap(
            spacing: isMobile ? 6 : 8,
            runSpacing: isMobile ? 6 : 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: ZplayRadius.smAll,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 8 : 10,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: _ctrl.isScraping
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tokens.textPrimary,
                        ),
                      )
                    : Icon(
                        Icons.radar_rounded,
                        size: 16,
                        color: tokens.textPrimary,
                      ),
                label: Text(
                  _ctrl.isScraping
                      ? 'Finding…'
                      : (isMobile ? 'Generate' : 'Generate Portals'),
                  style: (isMobile ? ZplayType.caption : ZplayType.label).toStyle(color: tokens.textPrimary),
                ),
                onPressed: _ctrl.isScraping ? null : _ctrl.scrape,
              ),

              // Source Selector Popup/Dropdown Menu
              PopupMenuButton<CatalogSource>(
                tooltip: 'Choose Portal Source',
                initialValue: _ctrl.scrapeSource,
                onSelected: (s) {
                  _ctrl.setScrapeSource(s);
                  setState(() {});
                },
                shape: RoundedRectangleBorder(
                  borderRadius: ZplayRadius.mdAll,
                  side: BorderSide(color: tokens.borderStrong),
                ),
                color: tokens.surfaceOverlay,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 9 : 12,
                    vertical: isMobile ? 7.5 : 9.5,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.borderDefault,
                    borderRadius: ZplayRadius.smAll,
                    border: Border.all(
                      color: tokens.borderStrong,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _ctrl.scrapeSource == CatalogSource.cloudVault
                            ? Icons.cloud_done_rounded
                            : Icons.forum_rounded,
                        size: 14,
                        color: _ctrl.scrapeSource == CatalogSource.cloudVault
                            ? tokens.info
                            : tokens.danger,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _ctrl.scrapeSource == CatalogSource.cloudVault
                            ? 'Cloud Vault'
                            : 'Reddit',
                        style: (isMobile ? ZplayType.caption : ZplayType.label).toStyle(color: tokens.textPrimary),
                      ),
                      const SizedBox(width: ZplaySpacing.s2),
                      Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 18,
                        color: tokens.textEmphasis,
                      ),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: CatalogSource.cloudVault,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_done_rounded,
                          color: tokens.info,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Cloud Vault',
                                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: tokens.info.withValues(alpha: 0.2),
                                      borderRadius: ZplayRadius.xsAll,
                                    ),
                                    child: Text(
                                      '9.6k+',
                                      style: ZplayType.overline.toStyle(color: tokens.info),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'High-speed cloud database with live IPTV servers',
                                style: ZplayType.overline.toStyle(color: tokens.textEmphasis),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: CatalogSource.reddit,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.forum_rounded,
                          color: tokens.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Reddit Communities',
                                style: ZplayType.label.toStyle(color: tokens.textPrimary),
                              ),
                              Text(
                                'Scrapes live shared pastes from subreddits',
                                style: ZplayType.overline.toStyle(color: tokens.textEmphasis),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: tokens.textPrimary,
                  side: BorderSide(color: tokens.borderStrong),
                  shape: const RoundedRectangleBorder(
                    borderRadius: ZplayRadius.smAll,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 8 : 10,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  isMobile ? 'Add' : 'Add Portal',
                  style: (isMobile ? ZplayType.caption : ZplayType.label).toStyle(),
                ),
                onPressed: () => setState(() {
                  _showAddForm = !_showAddForm;
                }),
              ),

              if (_ctrl.verified.isNotEmpty)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isPortalsEditMode
                        ? tokens.info
                        : tokens.textPrimary,
                    side: BorderSide(
                      color: _isPortalsEditMode
                          ? tokens.info
                          : tokens.borderStrong,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ZplayRadius.smAll,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 9 : 12,
                      vertical: isMobile ? 8 : 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _isPortalsEditMode
                        ? Icons.edit_off_rounded
                        : Icons.edit_rounded,
                    size: 15,
                  ),
                  label: Text(
                    _isPortalsEditMode ? 'Done' : 'Manage',
                    style: (isMobile ? ZplayType.caption : ZplayType.label).toStyle(),
                  ),
                  onPressed: () {
                    setState(() {
                      _isPortalsEditMode = !_isPortalsEditMode;
                      if (!_isPortalsEditMode) _selectedPortalKeys.clear();
                    });
                  },
                ),
            ],
          ),

          // Selection Toolbar for Portals
          if (_isPortalsEditMode && _ctrl.verified.isNotEmpty) ...[
            const SizedBox(height: ZplaySpacing.s12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.12),
                borderRadius: ZplayRadius.smAll,
                border: Border.all(
                  color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          allSelected
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 17,
                          color: tokens.info,
                        ),
                        label: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: ZplayType.label.toStyle(),
                        ),
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              _selectedPortalKeys.clear();
                            } else {
                              _selectedPortalKeys.clear();
                              _selectedPortalKeys.addAll(
                                currentList.map((v) => v.key),
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(width: ZplaySpacing.s4),
                      Text(
                        '(${_selectedPortalKeys.length}/${currentList.length})',
                        style: ZplayType.caption.toStyle(color: tokens.textEmphasis),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Delete Selected
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.danger,
                          foregroundColor: tokens.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: ZplayRadius.smAll,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 14),
                        label: Text(
                          'Delete (${_selectedPortalKeys.length})',
                          style: ZplayType.caption.toStyle(),
                        ),
                        onPressed: _selectedPortalKeys.isEmpty
                            ? null
                            : _deleteSelectedPortals,
                      ),
                      // Delete All
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.danger,
                          side: BorderSide(color: tokens.danger),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: ZplayRadius.smAll,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _deleteAllPortals,
                        child: Text(
                          'Delete All',
                          style: ZplayType.caption.toStyle(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (_ctrl.statusText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _ctrl.statusText,
              style: ZplayType.caption.toStyle(color: tokens.info),
            ),
          ],

          // Add Manual Portal Form
          if (_showAddForm) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(ZplaySpacing.s16),
              decoration: BoxDecoration(
                color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                borderRadius: ZplayRadius.mdAll,
                border: Border.all(color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add Xtream Codes Portal',
                    style: ZplayType.body.copyWith(weight: FontWeight.w800).toStyle(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlCtrl,
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Server URL (e.g. http://example.com:8080)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: ZplaySpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userCtrl,
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: ZplaySpacing.s8),
                      Expanded(
                        child: TextField(
                          controller: _passCtrl,
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_ctrl.addError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _ctrl.addError!,
                      style: ZplayType.caption.toStyle(color: tokens.danger),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                      ),
                      onPressed: _ctrl.isAdding ? null : _submitAddPortal,
                      child: _ctrl.isAdding
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.textPrimary,
                              ),
                            )
                          : const Text('Verify & Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: ZplaySpacing.s12),

          // Source Filter Bar
          if (_ctrl.verified.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildSourceChip(
                    'all',
                    'All (${_ctrl.verified.length})',
                    Icons.apps_rounded,
                    palette,
                  ),
                  const SizedBox(width: 6),
                  _buildSourceChip(
                    'custom',
                    'My Portals (${_ctrl.verified.where((p) {
                      final s = p.portal.source.toLowerCase();
                      return s.isEmpty || s.contains('custom') || s.contains('manual');
                    }).length})',
                    Icons.lock_rounded,
                    palette,
                    activeColor: tokens.success,
                  ),
                  const SizedBox(width: 6),
                  _buildSourceChip(
                    'cloud',
                    'Cloud Vault (${_ctrl.verified.where((p) => p.portal.source.toLowerCase().contains('cloud') || p.portal.source.toLowerCase().contains('vault')).length})',
                    Icons.cloud_done_rounded,
                    palette,
                    activeColor: tokens.info,
                  ),
                  const SizedBox(width: 6),
                  _buildSourceChip(
                    'reddit',
                    'Reddit (${_ctrl.verified.where((p) => p.portal.source.toLowerCase().contains('reddit')).length})',
                    Icons.forum_rounded,
                    palette,
                    activeColor: tokens.danger,
                  ),
                  const SizedBox(width: 6),
                  _buildSourceChip(
                    'fav',
                    'Favorites ⭐ (${_ctrl.verified.where((p) => _ctrl.isFavoritePortal(p.key)).length})',
                    Icons.star_rounded,
                    palette,
                    activeColor: tokens.warning,
                  ),
                ],
              ),
            ),
            const SizedBox(height: ZplaySpacing.s12),
          ],

          // List of Portals
          Expanded(
            child: () {
              final portals = _filteredPortals;
              if (portals.isEmpty) {
                return Center(
                  child: Text(
                    _ctrl.verified.isEmpty
                        ? 'No verified portals. Tap "Generate Portals" (${_ctrl.scrapeSource == CatalogSource.cloudVault ? "Cloud Vault" : "Reddit"}) to auto-discover.'
                        : 'No portals found in "$_portalSourceFilter" filter.',
                    style: ZplayType.body.toStyle(color: tokens.textMuted),
                  ),
                );
              }

              return ListView.separated(
                itemCount: portals.length,
                separatorBuilder: (_, _) => const SizedBox(height: ZplaySpacing.s8),
                itemBuilder: (context, index) {
                  final p = portals[index];
                  final isFav = _ctrl.isFavoritePortal(p.key);
                  final isSelected = _selectedPortalKeys.contains(p.key);

                  final isRich =
                      IptvSettings.portalCardStyle.value ==
                      PortalCardStyle.rich;
                  final showExp =
                      IptvSettings.showPortalExpiry.value &&
                      p.expiry.isNotEmpty;
                  final showConn =
                      IptvSettings.showPortalConnections.value &&
                      p.maxConnections.isNotEmpty;

                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTapDown: (details) =>
                          _tapPosition = details.globalPosition,
                      onTap: () {
                        if (_isPortalsEditMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedPortalKeys.remove(p.key);
                            } else {
                              _selectedPortalKeys.add(p.key);
                            }
                          });
                        } else {
                          final tapPos = _tapPosition;
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            LiquidRevealRoute(
                              page: IptvPortalBrowserPage(portal: p),
                              tapPosition: tapPos,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 14,
                          vertical: isMobile ? 10 : (isRich ? 12 : 8),
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? palette.primaryColor.withValues(alpha: 0.15)
                              : tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                          borderRadius: ZplayRadius.smAll,
                          border: Border.all(
                            color: isSelected
                                ? palette.primaryColor
                                : tokens.borderDefault,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: _buildPortalCardContent(
                          context: context,
                          p: p,
                          isSelected: isSelected,
                          isFav: isFav,
                          isRich: isRich,
                          showExp: showExp,
                          showConn: showConn,
                          isMobile: isMobile,
                          palette: palette,
                        ),
                      ),
                    ),
                  );
                },
              );
            }(),
          ),
        ],
      ),
    );
  }

  Widget _buildPortalCardContent({
    required BuildContext context,
    required VerifiedPortal p,
    required bool isSelected,
    required bool isFav,
    required bool isRich,
    required bool showExp,
    required bool showConn,
    required bool isMobile,
    required AppThemePalette palette,
  }) {
    final tokens = context.tokens;
    final hasBadges = showExp || showConn || p.portal.source.isNotEmpty;

    // Action button helpers
    Widget buildCopyBtn() {
      return IconButton(
        icon: Icon(Icons.copy_rounded, color: tokens.textEmphasis, size: 17),
        tooltip: 'Copy Login (url:user:pass)',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () {
          final text =
              '${p.portal.url}:${p.portal.username}:${p.portal.password}';
          Clipboard.setData(ClipboardData(text: text));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Copied: $text'),
              duration: const Duration(seconds: 2),
              backgroundColor: context.tokens.surfaceOverlay,
            ),
          );
        },
      );
    }

    Widget buildFavBtn() {
      return IconButton(
        icon: Icon(
          isFav ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isFav ? tokens.warning : tokens.textMuted,
          size: 19,
        ),
        tooltip: isFav ? 'Remove Favorite' : 'Add to Favorites',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () => _ctrl.toggleFavoritePortal(p.key),
      );
    }

    Widget buildDeleteBtn() {
      return IconButton(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: tokens.danger,
          size: 18,
        ),
        tooltip: 'Remove Portal',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () => _ctrl.deletePortalsByKeys({p.key}),
      );
    }

    Widget buildLeadingIndicator() {
      if (_isPortalsEditMode) {
        return Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: isSelected ? palette.primaryColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? palette.primaryColor : tokens.textMuted,
              width: 2,
            ),
          ),
          child: isSelected
              ? Icon(Icons.check_rounded, color: tokens.textPrimary, size: 14)
              : null,
        );
      }
      return Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: tokens.success,
          shape: BoxShape.circle,
        ),
      );
    }

    Widget buildBadgesWrap() {
      return Wrap(
        spacing: 5,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showExp)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: palette.primaryColor.withValues(alpha: 0.15),
                borderRadius: ZplayRadius.xsAll,
              ),
              child: Text(
                'Exp: ${p.expiry}',
                style: ZplayType.overline.toStyle(color: palette.primaryColor),
              ),
            ),
          if (showConn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: tokens.borderDefault,
                borderRadius: ZplayRadius.xsAll,
              ),
              child: Text(
                'Conn: ${p.activeConnections}/${p.maxConnections}',
                style: ZplayType.overline.toStyle(color: tokens.textEmphasis),
              ),
            ),
          if (p.portal.source.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color:
                    p.portal.source.toLowerCase().contains('cloud') ||
                        p.portal.source.toLowerCase().contains('vault')
                    ? tokens.info.withValues(alpha: 0.15)
                    : (p.portal.source.toLowerCase().contains('reddit')
                          ? tokens.danger.withValues(alpha: 0.15)
                          : tokens.borderDefault),
                borderRadius: ZplayRadius.xsAll,
              ),
              child: Text(
                p.portal.source,
                style: ZplayType.overline.toStyle(
                  color:
                      p.portal.source.toLowerCase().contains('cloud') ||
                          p.portal.source.toLowerCase().contains('vault')
                      ? tokens.info
                      : (p.portal.source.toLowerCase().contains('reddit')
                            ? tokens.danger
                            : tokens.textEmphasis),
                ),
              ),
            ),
        ],
      );
    }

    if (isMobile) {
      // ── Mobile Responsive Card ──
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Status/Checkbox + Portal Name + Quick Action Buttons
          Row(
            children: [
              buildLeadingIndicator(),
              Expanded(
                child: Text(
                  p.name.isNotEmpty ? p.name : p.portal.url,
                  style: ZplayType.label.toStyle(color: tokens.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: ZplaySpacing.s4),
              buildCopyBtn(),
              const SizedBox(width: ZplaySpacing.s2),
              buildFavBtn(),
              if (!_isPortalsEditMode) ...[
                const SizedBox(width: ZplaySpacing.s2),
                buildDeleteBtn(),
              ],
            ],
          ),

          const SizedBox(height: ZplaySpacing.s4),

          // URL Row: Spans the full card width, strictly horizontal with ellipsis
          Row(
            children: [
              Icon(Icons.link_rounded, size: 13, color: tokens.textMuted),
              const SizedBox(width: ZplaySpacing.s4),
              Expanded(
                child: Text(
                  p.portal.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                ),
              ),
              if (!hasBadges) ...[
                const SizedBox(width: ZplaySpacing.s4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.textDisabled,
                  size: 17,
                ),
              ],
            ],
          ),

          // Badges & Navigation Row
          if (hasBadges) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: buildBadgesWrap()),
                Icon(
                  Icons.chevron_right_rounded,
                  color: tokens.textDisabled,
                  size: 17,
                ),
              ],
            ),
          ],
        ],
      );
    } else {
      // ── Desktop / Tablet Card ──
      return Row(
        children: [
          buildLeadingIndicator(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  p.name.isNotEmpty ? p.name : p.portal.url,
                  style: ZplayType.label.toStyle(color: tokens.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: ZplaySpacing.s2),
                Text(
                  p.portal.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZplayType.caption.toStyle(color: tokens.textMuted),
                ),
                if (hasBadges && isRich) ...[
                  const SizedBox(height: ZplaySpacing.s4),
                  buildBadgesWrap(),
                ],
              ],
            ),
          ),
          if (hasBadges && !isRich) ...[
            const SizedBox(width: ZplaySpacing.s8),
            buildBadgesWrap(),
          ],
          const SizedBox(width: 6),
          buildCopyBtn(),
          const SizedBox(width: ZplaySpacing.s2),
          buildFavBtn(),
          if (!_isPortalsEditMode) ...[
            const SizedBox(width: ZplaySpacing.s2),
            buildDeleteBtn(),
          ],
          const SizedBox(width: ZplaySpacing.s2),
          Icon(
            Icons.chevron_right_rounded,
            color: tokens.textMuted,
            size: 18,
          ),
        ],
      );
    }
  }

  Widget _buildSourceChip(
    String filterKey,
    String label,
    IconData icon,
    AppThemePalette palette, {
    Color? activeColor,
  }) {
    final tokens = context.tokens;
    final isSelected = _portalSourceFilter == filterKey;
    final color = activeColor ?? palette.primaryColor;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? tokens.textPrimary : tokens.textEmphasis,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: color.withValues(alpha: 0.3),
      backgroundColor: tokens.surfaceOverlay,
      labelStyle: ZplayType.caption.toStyle(color: isSelected ? tokens.textPrimary : tokens.textEmphasis),
      side: BorderSide(
        color: isSelected ? color : tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium),
        width: isSelected ? 1.5 : 1.0,
      ),
      shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _portalSourceFilter = filterKey;
          });
        }
      },
    );
  }

  Widget _buildM3uTab(bool isMobile) {
    final tokens = context.tokens;
    final palette = AppThemeService.currentPalette.value;
    final allSelected =
        _ctrl.m3uPlaylists.isNotEmpty &&
        _selectedM3uIds.length == _ctrl.m3uPlaylists.length;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryColor,
                  shape: const RoundedRectangleBorder(
                    borderRadius: ZplayRadius.smAll,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 14,
                    vertical: isMobile ? 8 : 10,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.playlist_add_rounded,
                  size: 17,
                  color: tokens.textPrimary,
                ),
                label: Text(
                  isMobile ? 'Add M3U' : 'Add M3U URL',
                  style: (isMobile ? ZplayType.caption : ZplayType.label).toStyle(color: tokens.textPrimary),
                ),
                onPressed: () => setState(() => _showM3uForm = !_showM3uForm),
              ),

              if (_ctrl.m3uPlaylists.isNotEmpty) ...[
                const SizedBox(width: ZplaySpacing.s8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isM3uEditMode
                        ? tokens.info
                        : tokens.textPrimary,
                    side: BorderSide(
                      color: _isM3uEditMode
                          ? tokens.info
                          : tokens.borderStrong,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: ZplayRadius.smAll,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 12,
                      vertical: isMobile ? 8 : 10,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _isM3uEditMode
                        ? Icons.edit_off_rounded
                        : Icons.edit_rounded,
                    size: 15,
                  ),
                  label: Text(
                    _isM3uEditMode ? 'Done' : 'Manage',
                    style: (isMobile ? ZplayType.caption : ZplayType.label).toStyle(),
                  ),
                  onPressed: () {
                    setState(() {
                      _isM3uEditMode = !_isM3uEditMode;
                      if (!_isM3uEditMode) _selectedM3uIds.clear();
                    });
                  },
                ),
              ],
            ],
          ),

          // Selection Toolbar for M3U
          if (_isM3uEditMode && _ctrl.m3uPlaylists.isNotEmpty) ...[
            const SizedBox(height: ZplaySpacing.s12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: palette.primaryColor.withValues(alpha: 0.12),
                borderRadius: ZplayRadius.smAll,
                border: Border.all(
                  color: palette.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: tokens.textPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          allSelected
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 17,
                          color: tokens.info,
                        ),
                        label: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: ZplayType.label.toStyle(),
                        ),
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              _selectedM3uIds.clear();
                            } else {
                              _selectedM3uIds.clear();
                              _selectedM3uIds.addAll(
                                _ctrl.m3uPlaylists.map((pl) => pl.id),
                              );
                            }
                          });
                        },
                      ),
                      const SizedBox(width: ZplaySpacing.s4),
                      Text(
                        '(${_selectedM3uIds.length}/${_ctrl.m3uPlaylists.length})',
                        style: ZplayType.caption.toStyle(color: tokens.textEmphasis),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Delete Selected
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.danger,
                          foregroundColor: tokens.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: ZplayRadius.smAll,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 14),
                        label: Text(
                          'Delete (${_selectedM3uIds.length})',
                          style: ZplayType.caption.toStyle(),
                        ),
                        onPressed: _selectedM3uIds.isEmpty
                            ? null
                            : _deleteSelectedM3u,
                      ),
                      // Delete All
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.danger,
                          side: BorderSide(color: tokens.danger),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: ZplayRadius.smAll,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _deleteAllM3u,
                        child: Text(
                          'Delete All',
                          style: ZplayType.caption.toStyle(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (_showM3uForm) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(ZplaySpacing.s16),
              decoration: BoxDecoration(
                color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                borderRadius: ZplayRadius.mdAll,
                border: Border.all(color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add M3U Playlist Subscription',
                    style: ZplayType.body.copyWith(weight: FontWeight.w800).toStyle(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _m3uNameCtrl,
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Playlist Name',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: ZplaySpacing.s8),
                  TextField(
                    controller: _m3uUrlCtrl,
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'M3U / M3U8 URL',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                      ),
                      onPressed: _ctrl.isM3uLoading ? null : _submitAddM3u,
                      child: _ctrl.isM3uLoading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.textPrimary,
                              ),
                            )
                          : const Text('Fetch & Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          Expanded(
            child: _ctrl.m3uPlaylists.isEmpty
                ? Center(
                    child: Text(
                      'No M3U playlists saved.',
                      style: ZplayType.body.toStyle(color: tokens.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: _ctrl.m3uPlaylists.length,
                    separatorBuilder: (_, _) => const SizedBox(height: ZplaySpacing.s8),
                    itemBuilder: (context, index) {
                      final pl = _ctrl.m3uPlaylists[index];
                      final isSelected = _selectedM3uIds.contains(pl.id);

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTapDown: (details) =>
                              _tapPosition = details.globalPosition,
                          onTap: () {
                            if (_isM3uEditMode) {
                              setState(() {
                                if (isSelected) {
                                  _selectedM3uIds.remove(pl.id);
                                } else {
                                  _selectedM3uIds.add(pl.id);
                                }
                              });
                            } else {
                              final tapPos = _tapPosition;
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                LiquidRevealRoute(
                                  page: IptvPortalBrowserPage(m3uPlaylist: pl),
                                  tapPosition: tapPos,
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 12 : 14,
                              vertical: isMobile ? 10 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.primaryColor.withValues(alpha: 0.15)
                                  : tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                              borderRadius: ZplayRadius.smAll,
                              border: Border.all(
                                color: isSelected
                                    ? palette.primaryColor
                                    : tokens.borderDefault,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: _buildM3uCardContent(
                              context: context,
                              pl: pl,
                              isSelected: isSelected,
                              isMobile: isMobile,
                              palette: palette,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildM3uCardContent({
    required BuildContext context,
    required M3uPlaylist pl,
    required bool isSelected,
    required bool isMobile,
    required AppThemePalette palette,
  }) {
    final tokens = context.tokens;
    Widget buildM3uCopyBtn() {
      return IconButton(
        icon: Icon(Icons.copy_rounded, color: tokens.textEmphasis, size: 17),
        tooltip: 'Copy Playlist URL',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () {
          final text = pl.sourceUrl ?? '';
          if (text.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Copied: $text'),
                duration: const Duration(seconds: 2),
                backgroundColor: context.tokens.surfaceOverlay,
              ),
            );
          }
        },
      );
    }

    Widget buildM3uDeleteBtn() {
      return IconButton(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: tokens.danger,
          size: 18,
        ),
        tooltip: 'Remove Playlist',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () => _ctrl.deleteM3uPlaylist(pl.id),
      );
    }

    Widget buildM3uLeading() {
      if (_isM3uEditMode) {
        return Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: isSelected ? palette.primaryColor : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? palette.primaryColor : tokens.textMuted,
              width: 2,
            ),
          ),
          child: isSelected
              ? Icon(Icons.check_rounded, color: tokens.textPrimary, size: 14)
              : null,
        );
      }
      return Container(
        margin: const EdgeInsets.only(right: 10),
        child: Icon(
          Icons.queue_music_rounded,
          color: palette.primaryColor,
          size: 19,
        ),
      );
    }

    if (isMobile) {
      // ── Mobile M3U Card ──
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              buildM3uLeading(),
              Expanded(
                child: Text(
                  pl.name,
                  style: ZplayType.label.toStyle(color: tokens.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: ZplaySpacing.s4),
              buildM3uCopyBtn(),
              if (!_isM3uEditMode) ...[
                const SizedBox(width: ZplaySpacing.s2),
                buildM3uDeleteBtn(),
              ],
            ],
          ),
          const SizedBox(height: ZplaySpacing.s4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: palette.primaryColor.withValues(alpha: 0.15),
                  borderRadius: ZplayRadius.xsAll,
                ),
                child: Text(
                  '${pl.channels.length} ch',
                  style: ZplayType.overline.toStyle(color: palette.primaryColor),
                ),
              ),
              if (pl.sourceUrl != null && pl.sourceUrl!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pl.sourceUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ZplayType.caption.toStyle(color: tokens.textMuted),
                  ),
                ),
              ] else
                const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.textDisabled,
                size: 17,
              ),
            ],
          ),
        ],
      );
    } else {
      // ── Desktop M3U Card ──
      return Row(
        children: [
          buildM3uLeading(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pl.name,
                  style: ZplayType.label.toStyle(color: tokens.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: ZplaySpacing.s2),
                Text(
                  '${pl.channels.length} channels ${pl.sourceUrl != null ? '· ${pl.sourceUrl!}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZplayType.caption.toStyle(color: tokens.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          buildM3uCopyBtn(),
          if (!_isM3uEditMode) ...[
            const SizedBox(width: ZplaySpacing.s2),
            buildM3uDeleteBtn(),
          ],
          const SizedBox(width: ZplaySpacing.s2),
          Icon(
            Icons.chevron_right_rounded,
            color: tokens.textMuted,
            size: 18,
          ),
        ],
      );
    }
  }
}
