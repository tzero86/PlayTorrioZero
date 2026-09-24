import 'package:flutter/material.dart';
import '../../models/iptv/iptv_models.dart';
import '../../services/iptv/hardcoded_channels.dart';
import '../../services/iptv/iptv_controller.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../widgets/common/focusable_card.dart';
import 'iptv_player_page.dart';

class IptvChannelSheet extends StatefulWidget {
  final HardcodedChannel channel;

  const IptvChannelSheet({super.key, required this.channel});

  static Future<void> show(BuildContext context, HardcodedChannel channel) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => IptvChannelSheet(channel: channel),
    );
  }

  @override
  State<IptvChannelSheet> createState() => _IptvChannelSheetState();
}

class _IptvChannelSheetState extends State<IptvChannelSheet> {
  final _ctrl = IptvController.instance;

  bool _isSelecting = false;
  final Set<String> _selectedUrls = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _ctrl.openHardcodedChannel(widget.channel);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _playHit(ChannelHit hit, [Offset? tapPos]) {
    final results = _ctrl.channelResults;
    if (results.isEmpty) return;
    final index = results.indexOf(hit);
    Navigator.pop(context);
    Navigator.push(
      context,
      LiquidRevealRoute(
        page: IptvPlayerPage(
          channel: widget.channel,
          hits: results,
          initialHitIndex: index >= 0 ? index : 0,
          isLive: true,
        ),
        tapPosition: tapPos,
      ),
    );
  }

  void _toggleSelection(String streamUrl) {
    setState(() {
      if (_selectedUrls.contains(streamUrl)) {
        _selectedUrls.remove(streamUrl);
      } else {
        _selectedUrls.add(streamUrl);
      }
    });
  }

  Future<void> _deleteSelectedStreams() async {
    if (_selectedUrls.isEmpty) return;
    final count = _selectedUrls.length;
    final toDelete = Set<String>.from(_selectedUrls);
    setState(() {
      _selectedUrls.clear();
      _isSelecting = false;
    });
    await _ctrl.removeChannelHits(widget.channel.id, toDelete);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $count stream feed${count == 1 ? "" : "s"}'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF1E2235),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final primaryColor = ch.gradient.isNotEmpty ? ch.gradient.first : const Color(0xFF7C5CFF);
    final secondaryColor = ch.gradient.length > 1 ? ch.gradient.last : const Color(0xFF00D2EF);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final results = _ctrl.channelResults;
        final isScanning = _ctrl.channelIsRunning;
        final status = _ctrl.channelStatus;
        final filteredResults = _searchQuery.trim().isEmpty
            ? results
            : results.where((hit) {
                final q = _searchQuery.trim().toLowerCase();
                final nameMatches = hit.stream.name.toLowerCase().contains(q);
                final portalMatches = hit.portal.name.toLowerCase().contains(q) ||
                    hit.portal.portal.username.toLowerCase().contains(q);
                final formatMatches = hit.stream.containerExt.toLowerCase().contains(q);
                return nameMatches || portalMatches || formatMatches;
              }).toList();
        final allSelected = results.isNotEmpty && _selectedUrls.length == results.length;

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0E15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 30,
                offset: Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header Banner
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 16, 10),
                child: Row(
                  children: [
                    // Channel Short / Icon Badge
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primaryColor, secondaryColor],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          ch.short,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Title & Category
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                ch.category,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ch.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pen / Edit Button
                    if (results.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          _isSelecting ? Icons.edit_off_rounded : Icons.edit_rounded,
                          color: _isSelecting ? const Color(0xFF00D2EF) : Colors.white70,
                          size: 22,
                        ),
                        tooltip: _isSelecting ? 'Cancel Selection' : 'Manage / Delete Channels',
                        onPressed: () {
                          setState(() {
                            _isSelecting = !_isSelecting;
                            if (!_isSelecting) _selectedUrls.clear();
                          });
                        },
                      ),

                    // Close Button
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Search Input Field
              if (results.isNotEmpty || _searchQuery.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty
                            ? const Color(0xFF7C5CFF).withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      cursorColor: const Color(0xFF7C5CFF),
                      decoration: InputDecoration(
                        hintText: 'Search ${results.length} channels (e.g. 1080p, 4K, feed name)...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: _searchQuery.isNotEmpty
                              ? const Color(0xFF7C5CFF)
                              : Colors.white.withValues(alpha: 0.4),
                          size: 20,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                    ),
                  ),
                ),

              // Selection Toolbar (when in edit mode)
              if (_isSelecting)
                Container(
                  margin: const EdgeInsets.fromLTRB(22, 0, 22, 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF7C5CFF).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      // Select All / Deselect All
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                          size: 18,
                          color: const Color(0xFF00D2EF),
                        ),
                        label: Text(
                          allSelected ? 'Deselect All' : 'Select All',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        onPressed: () {
                          setState(() {
                            if (allSelected) {
                              _selectedUrls.clear();
                            } else {
                              _selectedUrls.clear();
                              _selectedUrls.addAll(results.map((h) => h.streamUrl));
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${_selectedUrls.length}/${results.length})',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      // Delete Selected
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.delete_rounded, size: 15),
                        label: Text(
                          'Delete (${_selectedUrls.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _selectedUrls.isEmpty ? null : _deleteSelectedStreams,
                      ),
                    ],
                  ),
                ),

              // Status Bar / Progress
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      if (isScanning)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF7C5CFF),
                          ),
                        )
                      else
                        const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          status.isNotEmpty
                              ? status
                              : (_searchQuery.trim().isNotEmpty
                                  ? 'Found ${filteredResults.length} of ${results.length} feeds'
                                  : '${results.length} live stream feeds available'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isScanning)
                        FocusableCard(
                          onTap: _ctrl.stopChannelSearch,
                          builder: (context, state) => CardFocusRing(
                            focused: state.focused,
                            radius: BorderRadius.circular(6),
                            child: const Text(
                              'Stop',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Discovered Stream Hits List
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isScanning) ...[
                                const CircularProgressIndicator(color: Color(0xFF7C5CFF)),
                                const SizedBox(height: 16),
                                const Text(
                                  'Scanning all verified portals in parallel…',
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ] else ...[
                                const Icon(Icons.tv_off_rounded, color: Colors.white38, size: 48),
                                const SizedBox(height: 12),
                                const Text(
                                  'No alive streams discovered yet.',
                                  style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tap "Scan More Portals" to discover fresh feeds.',
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : (filteredResults.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.search_off_rounded, color: Colors.white38, size: 48),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No feeds match "$_searchQuery"',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: const Text(
                                      'Clear Search',
                                      style: TextStyle(
                                        color: Color(0xFF7C5CFF),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
                            physics: const BouncingScrollPhysics(),
                            itemCount: filteredResults.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final hit = filteredResults[index];
                              final isFav = _ctrl.isFavoriteHit(ch.id, hit);
                              final isSelected = _selectedUrls.contains(hit.streamUrl);

                              return FocusableCard(
                                onTap: () => _isSelecting
                                    ? _toggleSelection(hit.streamUrl)
                                    : _playHit(hit),
                                builder: (context, state) => CardFocusRing(
                                  focused: state.focused,
                                  radius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF7C5CFF).withValues(alpha: 0.15)
                                          : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSelected
                                            ? const Color(0xFF7C5CFF)
                                            : (isFav
                                                ? const Color(0xFF7C5CFF).withValues(alpha: 0.6)
                                                : Colors.white.withValues(alpha: 0.08)),
                                        width: isSelected || isFav ? 1.6 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        // Selection checkbox or Play icon
                                        if (_isSelecting)
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(0xFF7C5CFF)
                                                  : Colors.white.withValues(alpha: 0.06),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF7C5CFF)
                                                    : Colors.white38,
                                                width: 2,
                                              ),
                                            ),
                                            child: isSelected
                                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                                                : null,
                                          )
                                        else
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF7C5CFF).withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.play_arrow_rounded,
                                              color: Color(0xFF7C5CFF),
                                              size: 22,
                                            ),
                                          ),

                                        const SizedBox(width: 14),

                                        // Stream Info
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 7,
                                                    height: 7,
                                                    decoration: const BoxDecoration(
                                                      color: Colors.greenAccent,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.greenAccent,
                                                          blurRadius: 4,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      hit.stream.name,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14.5,
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Padding(
                                                padding: const EdgeInsets.only(left: 13),
                                                child: Text(
                                                  hit.portal.portal.username.isNotEmpty
                                                      ? hit.portal.portal.username
                                                      : (hit.portal.name.isNotEmpty
                                                          ? hit.portal.name
                                                          : 'Server ${index + 1}'),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.5),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Format Tag
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            hit.stream.containerExt.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(width: 8),

                                        // Favorite Pin
                                        IconButton(
                                          icon: Icon(
                                            isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                                            color: isFav ? const Color(0xFFFFC107) : Colors.white38,
                                            size: 22,
                                          ),
                                          onPressed: () => _ctrl.toggleFavoriteHit(hit),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          )),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
                ),
                child: Row(
                  children: [
                    // Quick Play Best
                    if (results.isNotEmpty)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C5CFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                          label: const Text(
                            'Watch Live',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          onPressed: filteredResults.isNotEmpty
                              ? () => _playHit(filteredResults.first)
                              : () => _playHit(results.first),
                        ),
                      ),

                    if (results.isNotEmpty) const SizedBox(width: 12),

                    // Scan More
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Scan More', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: isScanning ? null : () => _ctrl.getMoreChannels(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
