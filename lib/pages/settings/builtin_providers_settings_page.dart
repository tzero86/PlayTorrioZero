import 'package:flutter/material.dart';
import '../../services/scraper/builtin_providers_settings_service.dart';
import '../../widgets/common/animated_ambient_background.dart';

class BuiltinProvidersSettingsPage extends StatefulWidget {
  const BuiltinProvidersSettingsPage({super.key});

  @override
  State<BuiltinProvidersSettingsPage> createState() => _BuiltinProvidersSettingsPageState();
}

class _BuiltinProvidersSettingsPageState extends State<BuiltinProvidersSettingsPage> {
  final _service = BuiltinProvidersSettingsService.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service.init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 500;
    final isUltraCompact = screenWidth < 380;
    final isTabletOrDesktop = screenWidth >= 800;
    final horizontalPadding = isCompact ? 12.0 : (isTabletOrDesktop ? 24.0 : 16.0);

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
          'Built-in Providers',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: [
          ListenableBuilder(
            listenable: _service,
            builder: (context, _) {
              if (!_service.isCustom) return const SizedBox.shrink();
              return TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7C5CFF),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.restore_rounded, size: 18),
                label: const Text('Reset', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF151822),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      title: const Text('Reset Providers Order?', style: TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text(
                        'This will restore all 45 ZPlayHTTP providers to their default order and re-enable any disabled providers.',
                        style: TextStyle(fontSize: 13.5, color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C5CFF),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reset'),
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _service.resetToDefault();
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedAmbientBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListenableBuilder(
              listenable: _service,
              builder: (context, _) {
                final isCustom = _service.isCustom;
                final allOrdered = _service.getOrderedProviders();
                final filtered = _searchQuery.isEmpty
                    ? allOrdered
                    : allOrdered
                        .where((p) =>
                            p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            p.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            p.description.toLowerCase().contains(_searchQuery.toLowerCase()))
                        .toList();

                final activeCount = allOrdered.where((p) => _service.isProviderEnabled(p.id)).length;
                final totalCount = allOrdered.length;

                return ListView(
                  padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 32 + bottomInset),
                  children: [
                    // Mode Selector Header (Responsive)
                    _buildModeSelector(isCustom, isCompact),

                    const SizedBox(height: 18),

                    if (!isCustom) ...[
                      // Default mode info banner
                      _buildDefaultModeCard(totalCount, isCompact),
                    ] else ...[
                      // Custom mode explanation & priority banner
                      _buildPriorityNoticeBanner(isCompact),

                      const SizedBox(height: 16),

                      // Search & Quick Action Toolbar (Responsive)
                      _buildToolbar(activeCount, totalCount, isCompact),

                      const SizedBox(height: 14),

                      // Reorderable list or filtered list
                      if (filtered.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(Icons.search_off_rounded, size: 44, color: Colors.white.withValues(alpha: 0.2)),
                              const SizedBox(height: 12),
                              Text(
                                'No providers found matching "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54, fontSize: 13.5),
                              ),
                            ],
                          ),
                        )
                      else if (_searchQuery.isNotEmpty)
                        // Static list when filtered by search query
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final provider = filtered[index];
                            final rank = _service.getProviderRank(provider.id);
                            return _buildProviderTile(
                              provider,
                              rank,
                              isFiltered: true,
                              isCompact: isCompact,
                              isUltraCompact: isUltraCompact,
                            );
                          },
                        )
                      else
                        // Reorderable List
                        Theme(
                          data: Theme.of(context).copyWith(
                            canvasColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                          ),
                          child: ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            itemCount: allOrdered.length,
                            onReorder: (oldIndex, newIndex) {
                              _service.reorder(oldIndex, newIndex);
                            },
                            itemBuilder: (context, index) {
                              final provider = allOrdered[index];
                              return KeyedSubtree(
                                key: ValueKey('provider_${provider.id}'),
                                child: _buildProviderTile(
                                  provider,
                                  index,
                                  isFiltered: false,
                                  isCompact: isCompact,
                                  isUltraCompact: isUltraCompact,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector(bool isCustom, bool isCompact) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF13151C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            _buildModeTabItem(
              isSelected: !isCustom,
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Default Mode',
              subtitle: 'Standard auto-sorting across all 45 providers',
              activeColor: const Color(0xFF10B981),
              onTap: () => _service.setMode(BuiltinProvidersMode.defaultMode),
            ),
            const SizedBox(height: 4),
            _buildModeTabItem(
              isSelected: isCustom,
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF7C5CFF),
              title: 'Custom Mode',
              subtitle: 'Manual provider order, toggles & priority scraping',
              activeColor: const Color(0xFF7C5CFF),
              onTap: () => _service.setMode(BuiltinProvidersMode.customMode),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF13151C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModeTabItem(
              isSelected: !isCustom,
              icon: Icons.auto_awesome_rounded,
              iconColor: const Color(0xFF10B981),
              title: 'Default',
              subtitle: 'Standard auto-sorting',
              activeColor: const Color(0xFF10B981),
              onTap: () => _service.setMode(BuiltinProvidersMode.defaultMode),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _buildModeTabItem(
              isSelected: isCustom,
              icon: Icons.tune_rounded,
              iconColor: const Color(0xFF7C5CFF),
              title: 'Custom',
              subtitle: 'Manual order & toggles',
              activeColor: const Color(0xFF7C5CFF),
              onTap: () => _service.setMode(BuiltinProvidersMode.customMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabItem({
    required bool isSelected,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.20) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor.withValues(alpha: 0.45) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? activeColor : Colors.white54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? activeColor.withValues(alpha: 0.9) : Colors.white38,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 16, color: activeColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultModeCard(int totalCount, bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 16 : 22),
      decoration: BoxDecoration(
        color: const Color(0xFF13151C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Default Mode Active',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All $totalCount ZPlayHTTP providers are active and scraped concurrently.',
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 14),
          const Text(
            'In Default mode, ZPlay uses its native multi-source streaming engine. All providers run simultaneously, and results are smartly sorted by video resolution (4K, 1080p, 720p) and file size.',
            style: TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: isCompact ? double.infinity : null,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C5CFF),
                side: BorderSide(color: const Color(0xFF7C5CFF).withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: const Text('Switch to Custom Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              onPressed: () => _service.setMode(BuiltinProvidersMode.customMode),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityNoticeBanner(bool isCompact) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7C5CFF).withValues(alpha: 0.16),
            const Color(0xFF00E5FF).withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C5CFF).withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C5CFF).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF7C5CFF), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Priority Scrape & Result Sorting',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                SizedBox(height: 3),
                Text(
                  'Providers at the top scrape first, and their results strictly display at the top of stream results, no matter the file size or quality.',
                  style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(int activeCount, int totalCount, bool isCompact) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search input
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF13151C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search providers (e.g. CineSrc)...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12.5),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white38),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Actions and active count row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF13151C),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Text(
                  '$activeCount / $totalCount Active',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: activeCount > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.select_all_rounded, size: 15),
                    label: const Text('Enable All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () => _service.enableAll(),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white54,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.deselect_rounded, size: 15),
                    label: const Text('Disable All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    onPressed: () => _service.disableAll(),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
    }

    // Tablet & Desktop layout
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF13151C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search providers (e.g. CineSrc, Dulo)...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white38),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16, color: Colors.white38),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF13151C),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                '$activeCount / $totalCount Active',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: activeCount > 0 ? const Color(0xFF10B981) : Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.select_all_rounded, size: 16),
              label: const Text('Enable All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () => _service.enableAll(),
            ),
            const SizedBox(width: 6),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.deselect_rounded, size: 16),
              label: const Text('Disable All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              onPressed: () => _service.disableAll(),
            ),
            const Spacer(),
            if (_searchQuery.isNotEmpty)
              Text(
                'Clear search to drag & reorder',
                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildProviderTile(
    BuiltinProviderMeta provider,
    int index, {
    required bool isFiltered,
    required bool isCompact,
    required bool isUltraCompact,
  }) {
    final isEnabled = _service.isProviderEnabled(provider.id);
    final rank = index + 1;
    final isTop3 = rank <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF13151C).withValues(alpha: isEnabled ? 0.8 : 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEnabled
              ? (isTop3
                  ? const Color(0xFF7C5CFF).withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.08))
              : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8 : 12,
          vertical: isCompact ? 8 : 10,
        ),
        child: Row(
          children: [
            // Drag Handle (only when not searching)
            if (!isFiltered)
              ReorderableDragStartListener(
                index: index,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 3 : 6,
                    vertical: 8,
                  ),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: isCompact ? 18 : 20,
                    color: Colors.white.withValues(alpha: isEnabled ? 0.4 : 0.15),
                  ),
                ),
              ),

            // Rank Badge
            Container(
              width: isCompact ? 28 : 34,
              height: isCompact ? 28 : 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isTop3 && isEnabled
                    ? const Color(0xFF7C5CFF).withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isTop3 && isEnabled
                      ? const Color(0xFF7C5CFF).withValues(alpha: 0.6)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: FontWeight.w800,
                  color: isTop3 && isEnabled
                      ? const Color(0xFFA78BFA)
                      : (isEnabled ? Colors.white70 : Colors.white24),
                ),
              ),
            ),

            SizedBox(width: isCompact ? 8 : 12),

            // Name & Description
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isCompact ? 13.5 : 14.5,
                            fontWeight: FontWeight.w700,
                            color: isEnabled ? Colors.white : Colors.white38,
                          ),
                        ),
                      ),
                      if (!isEnabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Off',
                            style: TextStyle(fontSize: 9.5, color: Colors.white38, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompact ? 10.5 : 11.5,
                      color: isEnabled ? Colors.white.withValues(alpha: 0.5) : Colors.white24,
                    ),
                  ),
                ],
              ),
            ),

            // Move Up / Move Down Arrow Buttons (compact sizing)
            if (!isUltraCompact) ...[
              IconButton(
                icon: const Icon(Icons.arrow_upward_rounded),
                iconSize: isCompact ? 16 : 18,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: isCompact ? 28 : 34,
                  height: isCompact ? 28 : 34,
                ),
                color: isEnabled && index > 0 ? Colors.white70 : Colors.white12,
                tooltip: 'Move Up',
                onPressed: isEnabled && index > 0
                    ? () => _service.moveProvider(provider.id, -1)
                    : null,
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward_rounded),
                iconSize: isCompact ? 16 : 18,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(
                  width: isCompact ? 28 : 34,
                  height: isCompact ? 28 : 34,
                ),
                color: isEnabled ? Colors.white70 : Colors.white12,
                tooltip: 'Move Down',
                onPressed: isEnabled
                    ? () => _service.moveProvider(provider.id, 1)
                    : null,
              ),
            ],

            SizedBox(width: isCompact ? 4 : 8),

            // Enable / Disable Switch (compact)
            Transform.scale(
              scale: isCompact ? 0.82 : 0.95,
              child: Switch.adaptive(
                value: isEnabled,
                activeColor: const Color(0xFF7C5CFF),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) => _service.toggleProvider(provider.id, val),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
