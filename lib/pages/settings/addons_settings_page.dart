import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/addon/addon.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/storage/app_image_cache.dart';

class AddonsSettingsPage extends StatefulWidget {
  const AddonsSettingsPage({super.key});

  @override
  State<AddonsSettingsPage> createState() => _AddonsSettingsPageState();
}

class _AddonsSettingsPageState extends State<AddonsSettingsPage> {
  final _manager = AddonManager.instance;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _manager.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _addAddon() async {
    final url = await _showAddDialog();
    if (url == null || url.trim().isEmpty) return;

    setState(() => _isAdding = true);

    try {
      final addon = await _manager.addAddon(url);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${addon.manifest.name} installed successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<String?> _showAddDialog() {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Add Stremio Addon',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the Stremio addon manifest.json URL to install catalogs, metadata, streams, or subtitles.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.50),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(fontSize: 13.5, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'https://opensubtitles-v3.strem.io/manifest.json',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.22),
                    fontSize: 12.5,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF0D1017),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF7C5CFF)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (value) => Navigator.pop(context, value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Install',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemove(InstalledAddon addon) {
    if (addon.baseUrl.startsWith('builtin:') ||
        addon.manifest.id == 'builtin.playtorrio' ||
        addon.manifest.id == 'builtin.playtorriohttp') {
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Remove ${addon.manifest.name}?'),
          content: Text(
            'Its catalogs and metadata will be removed from your home page.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _manager.removeAddon(addon.manifest.id);
                setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Remove',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final addons = _manager.addons;

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1017),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Addons',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Description
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Addons provide metadata, catalogs, and streaming sources. Hold and drag to reorder priority. Providers higher up load and appear first in watch sources.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ),

              // Add Addon Button
              _AddAddonButton(isLoading: _isAdding, onTap: _addAddon),
              const SizedBox(height: 24),

              // Section Header
              Row(
                children: [
                  Text(
                    'INSTALLED PROVIDERS & ADDONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C5CFF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${addons.length} Total',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7C5CFF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Addons List or Empty State
              if (addons.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF12151E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.extension_off_rounded, size: 40, color: Colors.white.withValues(alpha: 0.25)),
                      const SizedBox(height: 12),
                      const Text(
                        'No Addons Installed',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Click "Add Addon" above to install a Stremio manifest URL.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: addons.length,
                  onReorder: (oldIdx, newIdx) async {
                    await _manager.reorderAddons(oldIdx, newIdx);
                    setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final addon = addons[index];
                    return Padding(
                      key: ValueKey(addon.manifest.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AddonCard(
                        index: index,
                        totalCount: addons.length,
                        addon: addon,
                        onMoveUp: index > 0
                            ? () async {
                                await _manager.moveAddonUp(index);
                                setState(() {});
                              }
                            : null,
                        onMoveDown: index < addons.length - 1
                            ? () async {
                                await _manager.moveAddonDown(index);
                                setState(() {});
                              }
                            : null,
                        onToggle: (enabled) async {
                          await _manager.toggleAddon(addon.manifest.id, enabled);
                          setState(() {});
                        },
                        onRatingChanged: (rating) async {
                          await _manager.setAddonAdultRating(
                            addon.manifest.id,
                            rating,
                          );
                          setState(() {});
                        },
                        onUpdateFeature: ({
                          enableCatalogs,
                          enableSearch,
                          enableSubtitles,
                          enableStreams,
                        }) async {
                          await _manager.updateAddonFeature(
                            addonId: addon.manifest.id,
                            enableCatalogs: enableCatalogs,
                            enableSearch: enableSearch,
                            enableSubtitles: enableSubtitles,
                            enableStreams: enableStreams,
                          );
                          setState(() {});
                        },
                        onRemove: () => _confirmRemove(addon),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Addon Card
// ─────────────────────────────────────────────────────────────────────────────

class _AddonCard extends StatelessWidget {
  final int index;
  final int totalCount;
  final InstalledAddon addon;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final ValueChanged<bool> onToggle;
  final ValueChanged<AddonAdultRating> onRatingChanged;
  final void Function({
    bool? enableCatalogs,
    bool? enableSearch,
    bool? enableSubtitles,
    bool? enableStreams,
  }) onUpdateFeature;
  final VoidCallback onRemove;

  const _AddonCard({
    required this.index,
    required this.totalCount,
    required this.addon,
    this.onMoveUp,
    this.onMoveDown,
    required this.onToggle,
    required this.onRatingChanged,
    required this.onUpdateFeature,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final m = addon.manifest;
    final isP2p = addon.manifest.id == 'builtin.playtorrio' || addon.baseUrl == 'builtin:playtorrio';
    final isHttp = addon.manifest.id == 'builtin.playtorriohttp' || addon.baseUrl == 'builtin:playtorriohttp';
    final isBuiltIn = isP2p || isHttp || addon.baseUrl.startsWith('builtin:');

    final hasCatalogs = m.supportsCatalog || m.catalogs.isNotEmpty;
    final hasSearch = m.catalogs.any((c) => c.supportsSearch) || m.supportsCatalog;
    final hasStreams = m.supportsStream;
    final hasSubtitles = m.supportsSubtitles;
    final hasAnyFeature = hasCatalogs || hasSearch || hasStreams || hasSubtitles;

    final providerColor = isP2p
        ? const Color(0xFF7C5CFF)
        : (isHttp ? const Color(0xFF10B981) : const Color(0xFF7C5CFF));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: addon.enabled
              ? providerColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // Reorder Drag Handle
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.drag_indicator_rounded,
                      color: Colors.white38,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Priority Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: providerColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: providerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '#${index + 1}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: providerColor,
                  ),
                ),
              ),

              // Addon Icon
              Container(
                width: 38,
                height: 38,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: providerColor.withValues(alpha: 0.14),
                ),
                child: isBuiltIn
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          'assets/icon_small.png',
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                        ),
                      )
                    : (m.logo != null && m.logo!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: m.logo!,
                              cacheManager: AppImageCache.manager,
                              memCacheWidth: 96,
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) => Icon(
                                Icons.extension_rounded,
                                color: providerColor,
                                size: 20,
                              )),
                          )
                        : Icon(
                            Icons.extension_rounded,
                            color: providerColor,
                            size: 20,
                          )),
              ),
              const SizedBox(width: 12),

              // Addon Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isBuiltIn) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: providerColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isP2p ? 'BUILT-IN TORRENT' : 'BUILT-IN HTTP',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: providerColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isP2p
                          ? 'Built-in TorrServer P2P streaming engine'
                          : (isHttp
                              ? 'Built-in multi-source fast HTTP scrapers'
                              : (m.supportsSubtitles && m.catalogs.isEmpty
                                  ? 'v${m.version}  ·  Subtitles Provider'
                                  : 'v${m.version}  ·  ${m.catalogs.length} catalog${m.catalogs.length == 1 ? '' : 's'}${m.supportsSubtitles ? '  ·  Subtitles' : ''}')),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Up/Down Quick Move Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
                    color: onMoveUp != null ? Colors.white70 : Colors.white24,
                    onPressed: onMoveUp,
                    tooltip: 'Move up in priority',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                    color: onMoveDown != null ? Colors.white70 : Colors.white24,
                    onPressed: onMoveDown,
                    tooltip: 'Move down in priority',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
              const SizedBox(width: 4),

              // Master Enable/Disable Switch
              Switch.adaptive(
                value: addon.enabled,
                onChanged: onToggle,
                activeColor: providerColor,
              ),
            ],
          ),

          // Description
          if (m.description != null && m.description!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              m.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.45),
                height: 1.35,
              ),
            ),
          ],

          // Feature Toggles Section
          if (addon.enabled && hasAnyFeature) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 13,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'FUNCTIONS',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (hasCatalogs)
                        _FeatureToggleChip(
                          icon: Icons.grid_view_rounded,
                          label: 'Catalogs',
                          count: m.catalogs.isNotEmpty ? m.catalogs.length : null,
                          isEnabled: addon.enableCatalogs,
                          onTap: () => onUpdateFeature(
                            enableCatalogs: !addon.enableCatalogs,
                          ),
                        ),
                      if (hasSearch)
                        _FeatureToggleChip(
                          icon: Icons.search_rounded,
                          label: 'Search',
                          isEnabled: addon.enableSearch,
                          onTap: () => onUpdateFeature(
                            enableSearch: !addon.enableSearch,
                          ),
                        ),
                      if (hasStreams)
                        _FeatureToggleChip(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Sources',
                          isEnabled: addon.enableStreams,
                          onTap: () => onUpdateFeature(
                            enableStreams: !addon.enableStreams,
                          ),
                        ),
                      if (hasSubtitles)
                        _FeatureToggleChip(
                          icon: Icons.subtitles_rounded,
                          label: 'Subtitles',
                          isEnabled: addon.enableSubtitles,
                          onTap: () => onUpdateFeature(
                            enableSubtitles: !addon.enableSubtitles,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          // Adult rating (gates this addon behind the global Adult Content switch)
          if (!isBuiltIn) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rating in AddonAdultRating.values)
                  _ratingChip(rating),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              m.isAdult
                  ? 'This addon declares itself 18+ in its manifest, so it is '
                        'treated as 18+ only whatever is selected above'
                  : switch (addon.adultRating) {
                      AddonAdultRating.sfw => 'No adult content from this addon',
                      AddonAdultRating.hybrid =>
                        'Shows with Adult Content off; its catalogs appear under 18+ in Discover',
                      AddonAdultRating.nsfw =>
                        'Hidden unless Adult Content is on',
                    },
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.4),
                height: 1.3,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Type badges + Remove
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: m.types.map(
                    (type) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.white.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).toList(),
                ),
              ),
              if (!isBuiltIn) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: Colors.red.withValues(alpha: 0.6),
                  onPressed: onRemove,
                  tooltip: 'Remove addon',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// One selectable adult rating. The selected state is the enabled one; tapping
  /// it again is a no-op, so the rating can never end up unset.
  Widget _ratingChip(AddonAdultRating rating) {
    final selected = addon.adultRating == rating;
    final (label, icon, color) = switch (rating) {
      AddonAdultRating.sfw => const (
        'SFW only',
        Icons.shield_outlined,
        Color(0xFF34D399),
      ),
      AddonAdultRating.hybrid => const (
        'Hybrid',
        Icons.balance_rounded,
        Color(0xFFF59E0B),
      ),
      AddonAdultRating.nsfw => const (
        '18+ only',
        Icons.eighteen_up_rating_rounded,
        Color(0xFFEF4444),
      ),
    };

    return _FeatureToggleChip(
      icon: icon,
      label: label,
      isEnabled: selected,
      showStateIcon: selected,
      activeColor: color,
      onTap: () {
        if (selected) return;
        onRatingChanged(rating);
      },
    );
  }
}

class _FeatureToggleChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final int? count;
  final bool isEnabled;
  final Color activeColor;
  final bool showStateIcon;
  final VoidCallback onTap;

  const _FeatureToggleChip({
    required this.icon,
    required this.label,
    this.count,
    required this.isEnabled,
    this.activeColor = const Color(0xFF7C5CFF),
    this.showStateIcon = true,
    required this.onTap,
  });

  @override
  State<_FeatureToggleChip> createState() => _FeatureToggleChipState();
}

class _FeatureToggleChipState extends State<_FeatureToggleChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.activeColor;
    final isEnabled = widget.isEnabled;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isEnabled
                ? (_hovered
                    ? activeColor.withValues(alpha: 0.25)
                    : activeColor.withValues(alpha: 0.15))
                : (_hovered
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isEnabled
                  ? activeColor.withValues(alpha: 0.50)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: isEnabled && _hovered
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: isEnabled
                    ? activeColor
                    : Colors.white.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 6),
              Text(
                widget.count != null
                    ? '${widget.label} (${widget.count})'
                    : widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isEnabled ? FontWeight.w600 : FontWeight.w500,
                  color: isEnabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                ),
              ),
              if (widget.showStateIcon) ...[
                const SizedBox(width: 6),
                Icon(
                  isEnabled
                      ? Icons.check_circle_rounded
                      : Icons.cancel_outlined,
                  size: 13,
                  color: isEnabled
                      ? const Color(0xFF34D399)
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add Addon Button
// ─────────────────────────────────────────────────────────────────────────────

class _AddAddonButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _AddAddonButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C5CFF).withValues(alpha: 0.25),
          ),
          color: const Color(0xFF7C5CFF).withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF7C5CFF),
                ),
              )
            else
              const Icon(Icons.add_rounded, color: Color(0xFF7C5CFF), size: 22),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'Installing...' : 'Add Addon',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7C5CFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
