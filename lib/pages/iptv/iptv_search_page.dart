import 'package:flutter/material.dart';
import '../../models/iptv/iptv_models.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/theme/design_tokens.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/iptv/iptv_channel_card.dart';
import 'iptv_channel_sheet.dart';

class IptvSearchPage extends StatefulWidget {
  final List<QuickChannel> quickChannels;

  const IptvSearchPage({super.key, this.quickChannels = const []});

  @override
  State<IptvSearchPage> createState() => _IptvSearchPageState();
}

class _IptvSearchPageState extends State<IptvSearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Combat',
    'Racing',
    'Sports',
    'Movies',
    'News',
    'Arabic',
    'Discovery',
    'Kids',
    'US',
    'UK',
    'CA',
    'Bay Area',
    'Int. Sports',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<HardcodedChannel> _filteredChannels() {
    final q = _query.toLowerCase();
    final results = <HardcodedChannel>[];

    // Search hardcoded channels
    for (final c in HardcodedChannels.all) {
      final matchesCategory = _selectedCategory == 'All' || c.category == _selectedCategory;
      if (!matchesCategory) continue;
      if (_query.trim().isEmpty) {
        results.add(c);
        continue;
      }
      if (c.name.toLowerCase().contains(q) ||
          c.short.toLowerCase().contains(q) ||
          c.keywords.any((k) => k.toLowerCase().contains(q))) {
        results.add(c);
      }
    }

    // Also search user-added Quick Channels
    for (final qc in widget.quickChannels) {
      if (_selectedCategory != 'All' && qc.category != _selectedCategory) continue;
      if (_query.trim().isEmpty) {
        results.add(_toHardcoded(qc));
        continue;
      }
      if (qc.name.toLowerCase().contains(q) ||
          qc.short.toLowerCase().contains(q) ||
          qc.keywords.any((k) => k.toLowerCase().contains(q))) {
        results.add(_toHardcoded(qc));
      }
    }

    return results;
  }

  static HardcodedChannel _toHardcoded(QuickChannel ch) => HardcodedChannel(
        id: 'qc_${ch.id}',
        name: ch.name,
        short: ch.short,
        category: ch.category,
        keywords: ch.keywords,
        gradient: ch.gradient,
        iconUrl: ch.iconUrl,
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final channels = _filteredChannels();
    final width = MediaQuery.sizeOf(context).width;

    // Responsive columns
    int crossAxisCount = 2;
    if (width > 1200) {
      crossAxisCount = 6;
    } else if (width > 900) {
      crossAxisCount = 5;
    } else if (width > 600) {
      crossAxisCount = 4;
    } else if (width > 420) {
      crossAxisCount = 3;
    }

    return Scaffold(
      backgroundColor: tokens.bg,
      // Opaque band with a hairline underneath — same treatment as the other
      // migrated shell pages, instead of a transparent bar over the grid.
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        shape: Border(bottom: tokens.hairline),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: tokens.textEmphasis),
          onPressed: () => Navigator.pop(context),
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: tokens.borderDefault,
            borderRadius: ZplayRadius.mdAll,
            border: Border.all(
              color: tokens.textPrimary.withValues(alpha: ZplayOpacity.overlayHover),
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            style: ZplayType.body.toStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search 60+ live channels, leagues, networks…',
              hintStyle: ZplayType.label.toStyle(color: tokens.textMuted),
              prefixIcon: Icon(Icons.search_rounded, color: tokens.accent, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close_rounded, color: tokens.textMuted, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category Pills Filter
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: ZplaySpacing.s20,
                vertical: ZplaySpacing.s8,
              ),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: ZplaySpacing.s8),
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;

                return FocusableCard(
                  onTap: () => setState(() => _selectedCategory = cat),
                  builder: (context, state) => CardFocusRing(
                    focused: state.focused,
                    radius: ZplayRadius.lgAll,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? tokens.accent : tokens.borderSubtle,
                        borderRadius: ZplayRadius.lgAll,
                        border: Border.all(
                          color: isSelected
                              ? tokens.accent
                              : tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: ZplayType.label.toStyle(
                            color: isSelected ? tokens.onAccent : tokens.textEmphasis,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Channel Grid
          Expanded(
            child: channels.isEmpty
                ? Center(
                    child: Text(
                      'No channels match your search.',
                      style: ZplayType.body.toStyle(color: tokens.textMuted),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      ZplaySpacing.s20,
                      ZplaySpacing.s12,
                      ZplaySpacing.s20,
                      30,
                    ),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: ZplaySpacing.s16,
                    ),
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final ch = channels[index];
                      return IptvChannelCard(
                        channel: ch,
                        onTap: () => IptvChannelSheet.show(context, ch),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
