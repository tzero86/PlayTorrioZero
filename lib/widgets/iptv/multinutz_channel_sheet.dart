import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../services/iptv/iptv_network.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../services/iptv/iptv_settings.dart';
import '../../models/iptv/iptv_models.dart';
import '../../pages/iptv/iptv_portal_browser_page.dart';
import '../../services/storage/app_image_cache.dart';

enum ChannelSheetTab { xtreme, m3u }

class MultiNutzChannelSheet extends StatefulWidget {
  final int cellIndex;
  final void Function(String streamUrl, String channelName) onChannelSelected;
  final ChannelSheetTab tabType;

  const MultiNutzChannelSheet({
    super.key,
    required this.cellIndex,
    required this.onChannelSelected,
    required this.tabType,
  });

  @override
  State<MultiNutzChannelSheet> createState() => _MultiNutzChannelSheetState();
}

class _MultiNutzChannelSheetState extends State<MultiNutzChannelSheet>
    with SingleTickerProviderStateMixin {
  final ctrl = IptvController.instance;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Widget-tree caches — cleared on data change, reused on reopen
  Widget? _cachedXtremeBody;
  Widget? _cachedM3uBody;

  void _clearXtremeCache() { _cachedXtremeBody = null; }
  void _clearM3uCache() { _cachedM3uBody = null; }

  // Portal management state
  bool _showAddForm = false;
  bool _isPortalsEditMode = false;
  final Set<String> _selectedPortalKeys = {};
  String _portalSourceFilter = 'all';


  // M3U management state
  bool _showM3uForm = false;
  bool _isM3uEditMode = false;
  final Set<String> _selectedM3uIds = {};

  // Add form controllers
  final _urlCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _m3uNameCtrl = TextEditingController();
  final _m3uUrlCtrl = TextEditingController();

  List<PortalChannelGroup> get _filteredXtremeGroups {
    if (_searchQuery.isEmpty) return ctrl.xtremeGroups;
    final q = _searchQuery.toLowerCase();
    return ctrl.xtremeGroups
        .map((group) {
          final filteredHits = group.hits
              .where((hit) =>
                  hit.stream.name.toLowerCase().contains(q) ||
                  group.portal.name.toLowerCase().contains(q))
              .toList();
          if (filteredHits.isEmpty) return null;
          return PortalChannelGroup(portal: group.portal, hits: filteredHits);
        })
        .whereType<PortalChannelGroup>()
        .toList();
  }

  List<M3uChannelGroup> get _filteredM3uGroups {
    if (_searchQuery.isEmpty) return ctrl.m3uGroups;
    final q = _searchQuery.toLowerCase();
    return ctrl.m3uGroups
        .map((group) {
          final filtered = group.channels
              .where((ch) =>
                  ch.name.toLowerCase().contains(q) ||
                  group.playlist.name.toLowerCase().contains(q))
              .toList();
          if (filtered.isEmpty) return null;
          return M3uChannelGroup(playlist: group.playlist, channels: filtered);
        })
        .whereType<M3uChannelGroup>()
        .toList();
  }

  List<VerifiedPortal> get _filteredPortals {
    return ctrl.verified.where((p) {
      if (_portalSourceFilter == 'fav') return ctrl.isFavoritePortal(p.key);
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
    if (widget.tabType == ChannelSheetTab.xtreme) {
      ctrl.xtremeGroups;
    } else {
      ctrl.m3uGroups;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _urlCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _m3uNameCtrl.dispose();
    _m3uUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitAddPortal() async {
    final success = await ctrl.addManual(
      url: _urlCtrl.text,
      username: _userCtrl.text,
      password: _passCtrl.text,
    );
    if (success && mounted) {
      _urlCtrl.clear();
      _userCtrl.clear();
      _passCtrl.clear();
      setState(() => _showAddForm = false);
      _clearXtremeCache();
    }
  }

  Future<void> _submitAddM3u() async {
    if (_m3uUrlCtrl.text.trim().isEmpty) return;
    await ctrl.addM3uFromUrl(_m3uNameCtrl.text, _m3uUrlCtrl.text.trim());
    if (mounted) {
      _m3uNameCtrl.clear();
      _m3uUrlCtrl.clear();
      setState(() => _showM3uForm = false);
      _clearM3uCache();
    }
  }

  Future<void> _deleteSelectedPortals() async {
    if (_selectedPortalKeys.isEmpty) return;
    final count = _selectedPortalKeys.length;
    final toDelete = Set<String>.from(_selectedPortalKeys);
    setState(() {
      _selectedPortalKeys.clear();
      _isPortalsEditMode = false;
    });
    await ctrl.deletePortalsByKeys(toDelete);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $count portal${count == 1 ? "" : "s"}'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.tokens.surfaceOverlay,
        ),
      );
    }
    _clearXtremeCache();
  }

  Future<void> _deleteAllPortals() async {
    final count = ctrl.verified.length;
    setState(() {
      _selectedPortalKeys.clear();
      _isPortalsEditMode = false;
    });
    await ctrl.deleteAllPortals();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed all $count portals'),
          duration: const Duration(seconds: 2),
          backgroundColor: context.tokens.surfaceOverlay,
        ),
      );
    }
    _clearXtremeCache();
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
      await ctrl.deleteM3uPlaylist(id);
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
    _clearM3uCache();
  }

  Future<void> _deleteAllM3u() async {
    final count = ctrl.m3uPlaylists.length;
    setState(() {
      _selectedM3uIds.clear();
      _isM3uEditMode = false;
    });
    await ctrl.deleteAllM3uPlaylists();
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

  Widget _buildSourceChip(
    String filterKey,
    String label,
    IconData icon,
    AppThemePalette palette, {
    Color? activeColor,
  }) {
    final isSelected = _portalSourceFilter == filterKey;
    final color = activeColor ?? palette.primaryColor;
    final tokens = context.tokens;

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
      labelStyle: ZplayType.bodySmall
          .copyWith(weight: isSelected ? FontWeight.w700 : FontWeight.w500)
          .toStyle(color: isSelected ? tokens.textPrimary : tokens.textEmphasis),
      side: BorderSide(
        color: isSelected ? color.withValues(alpha: 0.6) : tokens.borderDefault,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _portalSourceFilter = filterKey;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      color: tokens.bg,
      child: widget.tabType == ChannelSheetTab.xtreme ? _buildXtremeTab() : _buildM3uTab(),
    );
  }

  Widget _buildXtremeTab() {
    final palette = AppThemeService.currentPalette.value;
    final tokens = context.tokens;
    final groups = _filteredXtremeGroups;
    final portals = _filteredPortals;
    final allSelected = portals.isNotEmpty && _selectedPortalKeys.length == portals.length;

    // Return cached body when not searching — avoids rebuilding all ExpansionTiles
    if (_searchQuery.isEmpty && _cachedXtremeBody != null) {
      return _cachedXtremeBody!;
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(ZplaySpacing.s16, ZplaySpacing.s16, ZplaySpacing.s16, ZplaySpacing.s8),
          child: TextField(
            controller: _searchController,
            style: ZplayType.label.toStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search channels...',
              hintStyle: ZplayType.body.toStyle(color: tokens.textDisabled),
              prefixIcon: Icon(Icons.search_rounded, color: tokens.textDisabled),
              border: OutlineInputBorder(
                borderRadius: ZplayRadius.smAll,
                borderSide: tokens.hairlineStrong,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: ZplayRadius.smAll,
                borderSide: tokens.hairlineStrong,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: ZplayRadius.smAll,
                borderSide: BorderSide(color: palette.primaryColor),
              ),
              filled: true,
              fillColor: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),

        // Action Buttons Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryColor,
                  shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: ctrl.isScraping
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: tokens.textPrimary),
                      )
                    : Icon(Icons.radar_rounded, size: 16, color: tokens.textPrimary),
                label: Text(
                  ctrl.isScraping ? 'Finding…' : 'Generate',
                  style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                ),
                onPressed: ctrl.isScraping ? null : ctrl.scrape,
              ),

              PopupMenuButton<CatalogSource>(
                tooltip: 'Choose Portal Source',
                initialValue: ctrl.scrapeSource,
                onSelected: (s) {
                  ctrl.setScrapeSource(s);
                  setState(() {});
                },
                shape: RoundedRectangleBorder(
                  borderRadius: ZplayRadius.mdAll,
                  side: tokens.hairlineStrong,
                ),
                color: tokens.surfaceOverlay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: tokens.borderDefault,
                    borderRadius: ZplayRadius.smAll,
                    border: Border.all(color: tokens.borderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ctrl.scrapeSource == CatalogSource.cloudVault
                            ? Icons.cloud_done_rounded
                            : Icons.forum_rounded,
                        size: 14,
                        color: ctrl.scrapeSource == CatalogSource.cloudVault
                            ? tokens.info
                            : tokens.danger,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        ctrl.scrapeSource == CatalogSource.cloudVault ? 'Cloud Vault' : 'Reddit',
                        style: ZplayType.caption.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                      ),
                      const SizedBox(width: ZplaySpacing.s2),
                      Icon(Icons.arrow_drop_down_rounded, size: 18, color: tokens.textEmphasis),
                    ],
                  ),
                ),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: CatalogSource.cloudVault,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done_rounded, color: tokens.info, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text('Cloud Vault', style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary)),
                                  const SizedBox(width: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    child: Text('9.6k+', style: ZplayType.overline.copyWith(weight: FontWeight.w700).toStyle(color: tokens.info)),
                                  ),
                                 ],
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
                        Icon(Icons.forum_rounded, color: tokens.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Reddit Communities', style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary)),
                              Text('Live shared pastes from subreddits', style: ZplayType.caption.toStyle(color: tokens.textEmphasis)),
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
                shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Add Portal', style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle()),
              onPressed: () => setState(() => _showAddForm = !_showAddForm),
            ),
            if (ctrl.verified.isNotEmpty)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _isPortalsEditMode ? tokens.info : tokens.textPrimary,
                  side: BorderSide(color: _isPortalsEditMode ? tokens.info : tokens.borderStrong),
                  shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(_isPortalsEditMode ? Icons.edit_off_rounded : Icons.edit_rounded, size: 15),
                label: Text(_isPortalsEditMode ? 'Done' : 'Manage', style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle()),
                onPressed: () {
                  setState(() {
                    _isPortalsEditMode = !_isPortalsEditMode;
                    if (!_isPortalsEditMode) _selectedPortalKeys.clear();
                  });
                },
              ),
          ],
        ),
        ),

        // Selection Toolbar for Portals
        if (_isPortalsEditMode && ctrl.verified.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s8),
              decoration: BoxDecoration(
                color: palette.primaryColor.withValues(alpha: 0.12),
                borderRadius: ZplayRadius.smAll,
                border: Border.all(color: palette.primaryColor.withValues(alpha: 0.3)),
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
                          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8, vertical: ZplaySpacing.s4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                          size: 17,
                          color: tokens.info,
                        ),
                        label: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(),
                        ),
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              _selectedPortalKeys.clear();
                            } else {
                              _selectedPortalKeys.clear();
                              _selectedPortalKeys.addAll(portals.map((v) => v.key));
                            }
                          });
                        },
                      ),
                      const SizedBox(width: ZplaySpacing.s4),
                      Text(
                        '(${_selectedPortalKeys.length}/${portals.length})',
                        style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textEmphasis),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.danger,
                          foregroundColor: tokens.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8, vertical: 6),
                          shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 14),
                        label: Text(
                          'Delete (${_selectedPortalKeys.length})',
                          style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle(),
                        ),
                        onPressed: _selectedPortalKeys.isEmpty ? null : _deleteSelectedPortals,
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.danger,
                          side: BorderSide(color: tokens.danger),
                          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8, vertical: 6),
                          shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _deleteAllPortals,
                        child: Text('Delete All', style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        if (ctrl.statusText.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s4),
            child: Text(
              ctrl.statusText,
              style: ZplayType.bodySmall.toStyle(color: tokens.info),
            ),
          ),
        ],

        // Add Manual Portal Form
        if (_showAddForm) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s8),
            child: Container(
              padding: const EdgeInsets.all(ZplaySpacing.s16),
              decoration: BoxDecoration(
                color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                borderRadius: ZplayRadius.mdAll,
                border: Border.all(color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Xtream Codes Portal', style: ZplayType.body.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _urlCtrl,
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(labelText: 'Server URL (e.g. http://example.com:8080)', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: ZplaySpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _userCtrl,
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                          decoration: const InputDecoration(labelText: 'Username', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: ZplaySpacing.s8),
                      Expanded(
                        child: TextField(
                          controller: _passCtrl,
                          style: ZplayType.label.toStyle(color: tokens.textPrimary),
                          decoration: const InputDecoration(labelText: 'Password', isDense: true, border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  if (ctrl.addError != null) ...[
                    const SizedBox(height: 6),
                    Text(ctrl.addError!, style: ZplayType.bodySmall.toStyle(color: tokens.danger)),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppThemeService.currentPalette.value.primaryColor),
                      onPressed: ctrl.isAdding ? null : _submitAddPortal,
                      child: ctrl.isAdding
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.textPrimary))
                          : const Text('Verify & Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: ZplaySpacing.s8),

        // Source Filter Bar
        if (ctrl.verified.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildSourceChip('all', 'All (${ctrl.verified.length})', Icons.apps_rounded, palette),
                  const SizedBox(width: 6),
                  _buildSourceChip('custom', 'My Portals (${ctrl.verified.where((p) {
                    final s = p.portal.source.toLowerCase();
                    return s.isEmpty || s.contains('custom') || s.contains('manual');
                  }).length})', Icons.lock_rounded, palette, activeColor: tokens.success),
                  const SizedBox(width: 6),
                  _buildSourceChip('cloud', 'Cloud Vault (${ctrl.verified.where((p) => p.portal.source.toLowerCase().contains('cloud') || p.portal.source.toLowerCase().contains('vault')).length})', Icons.cloud_done_rounded, palette, activeColor: tokens.info),
                  const SizedBox(width: 6),
                  _buildSourceChip('reddit', 'Reddit (${ctrl.verified.where((p) => p.portal.source.toLowerCase().contains('reddit')).length})', Icons.forum_rounded, palette, activeColor: tokens.danger),
                  const SizedBox(width: 6),
                  _buildSourceChip('fav', 'Favorites ⭐ (${ctrl.verified.where((p) => ctrl.isFavoritePortal(p.key)).length})', Icons.star_rounded, palette, activeColor: tokens.warning),
                ],
              ),
            ),
          ),
          const SizedBox(height: ZplaySpacing.s8),
        ],

        // Portal List
        ...[
          if (portals.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.tv_off_rounded, size: 48, color: tokens.textDisabled),
                    const SizedBox(height: ZplaySpacing.s16),
                    Text(
                      _searchQuery.isEmpty ? 'No Xtream portals loaded' : 'No matching channels',
                      style: ZplayType.body.toStyle(color: tokens.textMuted),
                    ),
                  ],
                ),
              ),
            )
          else if (!_isPortalsEditMode && _searchQuery.isEmpty)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s8),
                itemCount: portals.length,
                separatorBuilder: (_, _) => const SizedBox(height: ZplaySpacing.s8),
                itemBuilder: (context, index) {
                  final p = portals[index];
                  return _buildXtremePortalCard(p, palette);
                },
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s8),
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: ZplaySpacing.s8),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  return _buildPortalChannelGroup(group, palette);
                },
              ),
            ),
        ],
      ],
    );
    if (_searchQuery.isEmpty) _cachedXtremeBody = body;
    return body;
  }

  Widget _buildXtremePortalCard(VerifiedPortal p, AppThemePalette palette) {
    final tokens = context.tokens;
    final showExp = IptvSettings.showPortalExpiry.value && p.expiry.isNotEmpty;
    final showConn = IptvSettings.showPortalConnections.value && p.maxConnections.isNotEmpty;
    final isFav = ctrl.isFavoritePortal(p.key);
    final hasBadges = showExp || showConn || p.portal.source.isNotEmpty;
    final isSelected = _isPortalsEditMode && _selectedPortalKeys.contains(p.key);

    Widget buildCopyBtn() {
      return IconButton(
        icon: Icon(Icons.copy_rounded, color: tokens.textEmphasis, size: 17),
        tooltip: 'Copy Login (url:user:pass)',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () {
          final text = '${p.portal.url}:${p.portal.username}:${p.portal.password}';
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
        onPressed: () => ctrl.toggleFavoritePortal(p.key),
      );
    }

    Widget buildDeleteBtn() {
      return IconButton(
        icon: Icon(Icons.delete_outline_rounded, color: tokens.danger, size: 18),
        tooltip: 'Remove Portal',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () => ctrl.deletePortalsByKeys({p.key}),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: ZplayRadius.smAll,
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
            Navigator.push(
              context,
              materialRoute(
                builder: (_) => IptvPortalBrowserPage(
                  portal: p,
                  returning: true,
                  onStreamSelected: widget.onChannelSelected,
                ),
              ),
            );
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: ZplaySpacing.s12),
          decoration: BoxDecoration(
            color: isSelected
                ? palette.primaryColor.withValues(alpha: 0.15)
                : tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
            borderRadius: ZplayRadius.smAll,
            border: Border.all(
              color: isSelected ? palette.primaryColor : tokens.borderDefault,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (_isPortalsEditMode)
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? palette.primaryColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? palette.primaryColor : tokens.textMuted, width: 2),
                      ),
                      child: isSelected ? Icon(Icons.check_rounded, color: tokens.textPrimary, size: 14) : null,
                    )
                  else
                    SizedBox(width: 18, height: 8, child: DecoratedBox(decoration: BoxDecoration(color: tokens.success, shape: BoxShape.circle))),
                  Expanded(
                    child: Text(
                      p.name.isNotEmpty ? p.name : p.portal.url,
                      style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_isPortalsEditMode) ...[
                    const SizedBox(width: ZplaySpacing.s4),
                    buildCopyBtn(),
                    const SizedBox(width: ZplaySpacing.s2),
                    buildFavBtn(),
                    const SizedBox(width: ZplaySpacing.s2),
                    buildDeleteBtn(),
                  ],
                  const SizedBox(width: ZplaySpacing.s2),
                  Icon(Icons.chevron_right_rounded, color: tokens.textMuted, size: 18),
                ],
              ),
              const SizedBox(height: ZplaySpacing.s4),
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
                ],
              ),
              if (hasBadges) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
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
                              child: Text('Exp: ${p.expiry}', style: ZplayType.overline.copyWith(weight: FontWeight.w700).toStyle(color: palette.primaryColor)),
                            ),
                          if (showConn)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: tokens.borderDefault,
                                borderRadius: ZplayRadius.xsAll,
                              ),
                              child: Text('Conn: ${p.activeConnections}/${p.maxConnections}', style: ZplayType.overline.toStyle(color: tokens.textEmphasis)),
                            ),
                          if (p.portal.source.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: p.portal.source.toLowerCase().contains('cloud') || p.portal.source.toLowerCase().contains('vault')
                                    ? tokens.info.withValues(alpha: 0.15)
                                    : (p.portal.source.toLowerCase().contains('reddit')
                                        ? tokens.danger.withValues(alpha: 0.15)
                                        : tokens.borderDefault),
                                borderRadius: ZplayRadius.xsAll,
                              ),
                              child: Text(
                                p.portal.source,
                                style: ZplayType.overline
                                    .copyWith(weight: FontWeight.w700)
                                    .toStyle(
                                      color: p.portal.source.toLowerCase().contains('cloud') || p.portal.source.toLowerCase().contains('vault')
                                          ? tokens.info
                                          : (p.portal.source.toLowerCase().contains('reddit')
                                              ? tokens.danger
                                              : tokens.textEmphasis),
                                    ),
                              ),
                            ),
],
                      ),
                    ),
                  ],
                ),
              ],

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortalChannelGroup(PortalChannelGroup group, AppThemePalette palette) {
    final tokens = context.tokens;
    final isRich = IptvSettings.portalCardStyle.value == PortalCardStyle.rich;
    final showExp = IptvSettings.showPortalExpiry.value && group.portal.expiry.isNotEmpty;
    final showConn = IptvSettings.showPortalConnections.value && group.portal.maxConnections.isNotEmpty;
    final isSelected = _isPortalsEditMode && _selectedPortalKeys.contains(group.portal.key);
    final isFav = ctrl.isFavoritePortal(group.portal.key);

    Widget buildCopyBtn() {
      return IconButton(
        icon: Icon(Icons.copy_rounded, color: tokens.textEmphasis, size: 17),
        tooltip: 'Copy Login (url:user:pass)',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () {
          final text = '${group.portal.portal.url}:${group.portal.portal.username}:${group.portal.portal.password}';
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
        onPressed: () => ctrl.toggleFavoritePortal(group.portal.key),
      );
    }

    Widget buildDeleteBtn() {
      return IconButton(
        icon: Icon(Icons.delete_outline_rounded, color: tokens.danger, size: 18),
        tooltip: 'Remove Portal',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () => ctrl.deletePortalsByKeys({group.portal.key}),
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
                'Exp: ${group.portal.expiry}',
                style: ZplayType.overline.copyWith(weight: FontWeight.w700).toStyle(color: palette.primaryColor),
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
                'Conn: ${group.portal.activeConnections}/${group.portal.maxConnections}',
                style: ZplayType.overline.toStyle(color: tokens.textEmphasis),
              ),
            ),
          if (group.portal.portal.source.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: group.portal.portal.source.toLowerCase().contains('cloud') || group.portal.portal.source.toLowerCase().contains('vault')
                    ? tokens.info.withValues(alpha: 0.15)
                    : (group.portal.portal.source.toLowerCase().contains('reddit')
                        ? tokens.danger.withValues(alpha: 0.15)
                        : tokens.borderDefault),
                borderRadius: ZplayRadius.xsAll,
              ),
              child: Text(
                group.portal.portal.source,
                style: ZplayType.overline
                    .copyWith(weight: FontWeight.w700)
                    .toStyle(
                      color: group.portal.portal.source.toLowerCase().contains('cloud') || group.portal.portal.source.toLowerCase().contains('vault')
                          ? tokens.info
                          : (group.portal.portal.source.toLowerCase().contains('reddit')
                              ? tokens.danger
                              : tokens.textEmphasis),
                    ),
              ),
            ),
        ],
      );
    }

    return ExpansionTile(
      collapsedShape: const RoundedRectangleBorder(),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium)),
      ),
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      title: Row(
        children: [
          if (_isPortalsEditMode)
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? palette.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? palette.primaryColor : tokens.textMuted, width: 2),
              ),
              child: isSelected ? Icon(Icons.check_rounded, color: tokens.textPrimary, size: 14) : null,
            )
          else
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: tokens.success, shape: BoxShape.circle),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        group.portal.name.isNotEmpty ? group.portal.name : group.portal.portal.url,
                        style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isPortalsEditMode) ...[
                      const SizedBox(width: ZplaySpacing.s4),
                      buildCopyBtn(),
                      const SizedBox(width: ZplaySpacing.s2),
                      buildFavBtn(),
                      const SizedBox(width: ZplaySpacing.s2),
                      buildDeleteBtn(),
                    ],
                  ],
                ),
                const SizedBox(height: ZplaySpacing.s2),
                Text(
                  group.portal.portal.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                ),
                if ((showExp || showConn || group.portal.portal.source.isNotEmpty) && isRich) ...[
                  const SizedBox(height: ZplaySpacing.s4),
                  buildBadgesWrap(),
                ],
              ],
            ),
          ),
          if ((_isPortalsEditMode || !(showExp || showConn || group.portal.portal.source.isNotEmpty) || !isRich))
            const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: tokens.textMuted, size: 18),
        ],
      ),
      children: group.hits.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(ZplaySpacing.s16),
                child: Center(
                  child: Text(
                    'No live channels available for this portal',
                    style: ZplayType.bodySmall.toStyle(color: tokens.textMuted),
                  ),
                ),
              ),
            ]
          : [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s4),
                child: Text(
                  '${group.hits.length} live channels',
                  style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                ),
              ),
               ConstrainedBox(
                 constraints: const BoxConstraints(maxHeight: 320),
                 child: ListView.separated(
                   shrinkWrap: false,
                   physics: const ClampingScrollPhysics(),
                   padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s4),
                   itemCount: group.hits.length,
                   separatorBuilder: (_, _) => const SizedBox(height: ZplaySpacing.s4),
                   itemBuilder: (context, hitIndex) {
                     final hit = group.hits[hitIndex];
                     return _buildChannelHitItem(hit, hitIndex);
                   },
                 ),
               ),
            ],
    );
  }

  Widget _buildChannelHitItem(ChannelHit hit, int hitIndex) {
    final tokens = context.tokens;
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: hit.stream.icon.isNotEmpty
            ? ClipRRect(
                borderRadius: ZplayRadius.xsAll,
                child: CachedNetworkImage(imageUrl: hit.stream.icon, cacheManager: AppImageCache.manager,
 memCacheWidth: 96, width: 24, height: 24, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.tv, color: tokens.textDisabled)),
              )
            : Icon(Icons.tv, color: tokens.textDisabled, size: 24),
        title: Text(
          hit.stream.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ZplayType.label.toStyle(color: tokens.textPrimary),
        ),
        subtitle: Text(
          hit.stream.containerExt.toUpperCase(),
          style: ZplayType.overline.toStyle(color: tokens.textMuted),
        ),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s4),
        shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
        tileColor: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
        hoverColor: tokens.borderDefault,
        onTap: () {
          Navigator.pop(context);
          widget.onChannelSelected(hit.streamUrl, hit.stream.name);
        },
      ),
    );
  }

  Widget _buildM3uTab() {
    final palette = AppThemeService.currentPalette.value;
    final tokens = context.tokens;
    final groups = _filteredM3uGroups;
    final allSelected = ctrl.m3uPlaylists.isNotEmpty && _selectedM3uIds.length == ctrl.m3uPlaylists.length;

    // Return cached body when not searching — avoids rebuilding all ExpansionTiles
    if (_searchQuery.isEmpty && _cachedM3uBody != null) {
      return _cachedM3uBody!;
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(ZplaySpacing.s16, ZplaySpacing.s16, ZplaySpacing.s16, ZplaySpacing.s8),
          child: TextField(
            controller: _searchController,
            style: ZplayType.label.toStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search channels...',
              hintStyle: ZplayType.body.toStyle(color: tokens.textDisabled),
              prefixIcon: Icon(Icons.search_rounded, color: tokens.textDisabled),
              border: OutlineInputBorder(
                borderRadius: ZplayRadius.smAll,
                borderSide: tokens.hairlineStrong,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: ZplayRadius.smAll,
                borderSide: tokens.hairlineStrong,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: ZplayRadius.smAll,
                borderSide: BorderSide(color: palette.primaryColor),
              ),
              filled: true,
              fillColor: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),

        // Action Buttons Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s8),
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primaryColor,
                  shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.playlist_add_rounded, size: 17, color: tokens.textPrimary),
                label: Text('Add M3U URL', style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle()),
                onPressed: () => setState(() => _showM3uForm = !_showM3uForm),
              ),
              if (ctrl.m3uPlaylists.isNotEmpty) ...[
                const SizedBox(width: ZplaySpacing.s8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _isM3uEditMode ? tokens.info : tokens.textPrimary,
                    side: BorderSide(color: _isM3uEditMode ? tokens.info : tokens.borderStrong),
                    shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s8),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(_isM3uEditMode ? Icons.edit_off_rounded : Icons.edit_rounded, size: 15),
                  label: Text(_isM3uEditMode ? 'Done' : 'Manage', style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle()),
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
        ),

        // Selection Toolbar for M3U
        if (_isM3uEditMode && ctrl.m3uPlaylists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s8),
              decoration: BoxDecoration(
                color: palette.primaryColor.withValues(alpha: 0.12),
                borderRadius: ZplayRadius.smAll,
                border: Border.all(color: palette.primaryColor.withValues(alpha: 0.3)),
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
                          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8, vertical: ZplaySpacing.s4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                          size: 17,
                          color: tokens.info,
                        ),
                        label: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(),
                        ),
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              _selectedM3uIds.clear();
                            } else {
                              _selectedM3uIds.clear();
                              _selectedM3uIds.addAll(ctrl.m3uPlaylists.map((pl) => pl.id));
                            }
                          });
                        },
                      ),
                      const SizedBox(width: ZplaySpacing.s4),
                      Text(
                        '(${_selectedM3uIds.length}/${ctrl.m3uPlaylists.length})',
                        style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textEmphasis),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.danger,
                          foregroundColor: tokens.textPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8, vertical: 6),
                          shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 14),
                        label: Text(
                          'Delete (${_selectedM3uIds.length})',
                          style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle(),
                        ),
                        onPressed: _selectedM3uIds.isEmpty ? null : _deleteSelectedM3u,
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.danger,
                          side: BorderSide(color: tokens.danger),
                          padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s8, vertical: 6),
                          shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _deleteAllM3u,
                        child: Text('Delete All', style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle()),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],

        // Add M3U Form
        if (_showM3uForm) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s8),
            child: Container(
              padding: const EdgeInsets.all(ZplaySpacing.s16),
              decoration: BoxDecoration(
                color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                borderRadius: ZplayRadius.mdAll,
                border: Border.all(color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add M3U Playlist Subscription', style: ZplayType.body.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _m3uNameCtrl,
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(labelText: 'Playlist Name', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: ZplaySpacing.s8),
                  TextField(
                    controller: _m3uUrlCtrl,
                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                    decoration: const InputDecoration(labelText: 'M3U / M3U8 URL', isDense: true, border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppThemeService.currentPalette.value.primaryColor),
                      onPressed: ctrl.isM3uLoading ? null : _submitAddM3u,
                      child: ctrl.isM3uLoading
                          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: tokens.textPrimary))
                          : const Text('Fetch & Save'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: ZplaySpacing.s8),

        // Channel Groups List
        if (groups.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.playlist_play_rounded, size: 48, color: tokens.textDisabled),
                  const SizedBox(height: ZplaySpacing.s16),
                  Text(
                    _searchQuery.isEmpty ? 'No M3U playlists loaded' : 'No matching channels',
                    style: ZplayType.body.toStyle(color: tokens.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s8),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: ZplaySpacing.s8),
              itemBuilder: (context, index) {
                final group = groups[index];
                return _buildM3uChannelGroup(group, palette);
              },
            ),
          ),
      ],
    );
    if (_searchQuery.isEmpty) _cachedM3uBody = body;
    return body;
  }

  Widget _buildM3uChannelGroup(M3uChannelGroup group, AppThemePalette palette) {
    final tokens = context.tokens;
    final isSelected = _isM3uEditMode && _selectedM3uIds.contains(group.playlist.id);

    Widget buildCopyBtn() {
      return IconButton(
        icon: Icon(Icons.copy_rounded, color: tokens.textEmphasis, size: 17),
        tooltip: 'Copy Playlist URL',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () {
          final text = group.playlist.sourceUrl ?? '';
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

    Widget buildDeleteBtn() {
      return IconButton(
        icon: Icon(Icons.delete_outline_rounded, color: tokens.danger, size: 18),
        tooltip: 'Remove Playlist',
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(5),
        constraints: const BoxConstraints(),
        onPressed: () => ctrl.deleteM3uPlaylist(group.playlist.id),
      );
    }

    return ExpansionTile(
      collapsedShape: const RoundedRectangleBorder(),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium)),
      ),
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      title: Row(
        children: [
          if (_isM3uEditMode)
            Container(
              width: 22,
              height: 22,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? palette.primaryColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? palette.primaryColor : tokens.textMuted, width: 2),
              ),
              child: isSelected ? Icon(Icons.check_rounded, color: tokens.textPrimary, size: 14) : null,
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 10),
              child: Icon(Icons.queue_music_rounded, color: palette.primaryColor, size: 19),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.playlist.name,
                  style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: ZplaySpacing.s2),
                Text(
                  '${group.channels.length} channels${group.playlist.sourceUrl != null ? ' · ${group.playlist.sourceUrl!}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ZplayType.caption.toStyle(color: tokens.textMuted),
                ),
              ],
            ),
          ),
          if (!_isM3uEditMode) ...[
            const SizedBox(width: 6),
            buildCopyBtn(),
            const SizedBox(width: ZplaySpacing.s2),
            buildDeleteBtn(),
          ],
          const SizedBox(width: ZplaySpacing.s2),
          Icon(Icons.chevron_right_rounded, color: tokens.textMuted, size: 18),
        ],
      ),
      children: group.channels.isEmpty
          ? [
              Padding(
                padding: const EdgeInsets.all(ZplaySpacing.s16),
                child: Center(
                  child: Text(
                    'No channels in this playlist',
                    style: ZplayType.bodySmall.toStyle(color: tokens.textMuted),
                  ),
                ),
              ),
            ]
          : [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s4),
                child: Text(
                  '${group.channels.length} channels',
                  style: ZplayType.caption.toStyle(color: tokens.textSecondary),
                ),
              ),
               ConstrainedBox(
                 constraints: const BoxConstraints(maxHeight: 320),
                 child: ListView.separated(
                   shrinkWrap: false,
                   physics: const ClampingScrollPhysics(),
                   padding: const EdgeInsets.symmetric(horizontal: ZplaySpacing.s16, vertical: ZplaySpacing.s4),
                   itemCount: group.channels.length,
                   separatorBuilder: (_, _) => const SizedBox(height: ZplaySpacing.s4),
                   itemBuilder: (context, chIndex) {
                  final ch = group.channels[chIndex];
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: ZplayRadius.smAll,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onChannelSelected(ch.url, ch.name);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: ZplaySpacing.s8),
                        decoration: BoxDecoration(
                          color: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                          borderRadius: ZplayRadius.smAll,
                          border: Border.all(color: tokens.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            if (ch.logo.isNotEmpty)
                              ClipRRect(
                                borderRadius: ZplayRadius.xsAll,
                                child: CachedNetworkImage(imageUrl: ch.logo, cacheManager: AppImageCache.manager,
 memCacheWidth: 96, width: 24, height: 24, fit: BoxFit.cover, errorWidget: (_, __, ___) => Icon(Icons.tv, color: tokens.textDisabled)),
                              )
                            else
                              Icon(Icons.tv, color: tokens.textDisabled, size: 24),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ch.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: ZplayType.label.toStyle(color: tokens.textPrimary),
                                  ),
                                  if (ch.group.isNotEmpty)
                                    Text(
                                      ch.group,
                                      style: ZplayType.overline.toStyle(color: tokens.textMuted),
                                    ),
                                ],
                              ),
                            ),
                            Icon(Icons.play_arrow_rounded, color: tokens.success, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              ),
            ],
    );
  }
}
