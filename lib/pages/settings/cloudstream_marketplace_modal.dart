import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/cloudstream/cloudstream_manager.dart';
import '../../services/cloudstream/marketplace/cloudstream_marketplace_service.dart';
import 'cloudstream_repo_modal.dart';

class CloudStreamMarketplaceModal extends StatefulWidget {
  const CloudStreamMarketplaceModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CloudStreamMarketplaceModal(),
    );
  }

  @override
  State<CloudStreamMarketplaceModal> createState() => _CloudStreamMarketplaceModalState();
}

class _CloudStreamMarketplaceModalState extends State<CloudStreamMarketplaceModal> {
  final _manager = CloudStreamManager.instance;
  final _service = CloudStreamMarketplaceService.instance;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _categoryScrollController = ScrollController();

  List<CloudStreamMarketplaceRepo> _repos = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final Set<String> _expandedRepos = {};
  final Set<String> _addingRepoUrls = {};

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRepos({bool forceRefresh = false}) async {
    setState(() {
      if (forceRefresh) {
        _isRefreshing = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final list = await _service.getRepos(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _repos = list;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  List<CloudStreamMarketplaceRepo> get _filteredRepos {
    var list = _repos;
    if (_selectedCategory != 'All') {
      list = list.where((r) => r.category == _selectedCategory).toList();
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return list;

    return list.where((r) {
      final nameMatch = r.name.toLowerCase().contains(query);
      final catMatch = r.category.toLowerCase().contains(query);
      final pluginMatch = r.plugins.any((p) => p.toLowerCase().contains(query));
      return nameMatch || catMatch || pluginMatch;
    }).toList();
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'Turkish':
        return '🇹🇷';
      case 'Arabic':
        return '🇸🇦';
      case 'Hindi / Asian':
        return '🇮🇳';
      case 'French':
        return '🇫🇷';
      case 'Italian':
        return '🇮🇹';
      case 'German':
        return '🇩🇪';
      case 'Portuguese / Spanish':
        return '🇵🇹';
      case 'Vietnamese':
        return '🇻🇳';
      case 'Ukrainian':
        return '🇺🇦';
      case 'Anime / Cartoons':
        return '🎌';
      case 'Multi / English':
        return '🌐';
      default:
        return '📦';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Turkish':
        return const Color(0xFFEF4444);
      case 'Arabic':
        return const Color(0xFF10B981);
      case 'Hindi / Asian':
        return const Color(0xFFF59E0B);
      case 'French':
        return const Color(0xFF3B82F6);
      case 'Italian':
        return const Color(0xFF06B6D4);
      case 'German':
        return const Color(0xFFEAB308);
      case 'Portuguese / Spanish':
        return const Color(0xFF8B5CF6);
      case 'Vietnamese':
        return const Color(0xFFEC4899);
      case 'Ukrainian':
        return const Color(0xFF0EA5E9);
      case 'Anime / Cartoons':
        return const Color(0xFFA855F7);
      default:
        return const Color(0xFF7C5CFF);
    }
  }

  Future<void> _addRepo(CloudStreamMarketplaceRepo repo) async {
    setState(() => _addingRepoUrls.add(repo.url));

    try {
      await _manager.addRepo(repo.url);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('${repo.name} added successfully!')),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Offer to install plugins immediately
      final shouldInstallAll = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF151822),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Install ${repo.name} Plugins?'),
          content: Text(
            repo.plugins.isNotEmpty
                ? 'This repository includes ${repo.plugins.length} plugins (${repo.plugins.take(3).join(', ')}...). Install all plugins now so their stream sources appear immediately?'
                : 'Would you like to install plugins from this repository now?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Later', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Install All Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (shouldInstallAll == true && mounted) {
        await _installAllPlugins(repo.url);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _addingRepoUrls.remove(repo.url));
      }
    }
  }

  Future<void> _installAllPlugins(String repoUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151822),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Installing Repository Plugins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const CircularProgressIndicator(color: Color(0xFF7C5CFF)),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: _manager.busyMessage,
                builder: (context, msg, _) => Text(
                  msg.isEmpty ? 'Installing extensions...' : msg,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final count = await _manager.installAllFromRepo(repoUrl);
      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count plugins installed and ready!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Installation error: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1017),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C5CFF), Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Marketplace',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7C5CFF).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${_repos.length} Repos',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9D84FF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Direct install links & verified providers',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh list from web',
                  icon: _isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C5CFF)),
                        )
                      : Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.6)),
                  onPressed: _isRefreshing ? null : () => _loadRepos(forceRefresh: true),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF151822),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white, fontSize: 13.5),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search repository or plugin (e.g. Turkish, 3rabi, DiziBox, Shahid)...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 12.5,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: Colors.white.withValues(alpha: 0.4)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Category Chips Bar with desktop horizontal scroll arrows
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (_categoryScrollController.hasClients) {
                        final target = (_categoryScrollController.offset - 180).clamp(
                          0.0,
                          _categoryScrollController.position.maxScrollExtent,
                        );
                        _categoryScrollController.animateTo(
                          target,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: ListView.builder(
                      controller: _categoryScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: CloudStreamMarketplaceService.categories.length,
                      itemBuilder: (context, idx) {
                        final cat = CloudStreamMarketplaceService.categories[idx];
                        final isSelected = _selectedCategory == cat;
                        final count = cat == 'All' ? _repos.length : _repos.where((r) => r.category == cat).length;
                        final emoji = _getCategoryEmoji(cat);

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedCategory = cat),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF7C5CFF).withValues(alpha: 0.22)
                                    : const Color(0xFF151822),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF7C5CFF)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(emoji, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 6),
                                  Text(
                                    cat,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? Colors.white : Colors.white60,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: isSelected ? 0.2 : 0.08),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.white : Colors.white54,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (_categoryScrollController.hasClients) {
                        final target = (_categoryScrollController.offset + 180).clamp(
                          0.0,
                          _categoryScrollController.position.maxScrollExtent,
                        );
                        _categoryScrollController.animateTo(
                          target,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Repositories List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7C5CFF)),
                  )
                : _filteredRepos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: 12),
                            Text(
                              'No repositories found for "$_searchQuery"',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filteredRepos.length,
                        itemBuilder: (context, index) {
                          final repo = _filteredRepos[index];
                          final isInstalled = _manager.isRepoInstalled(repo.url);
                          final isAdding = _addingRepoUrls.contains(repo.url);
                          final isExpanded = _expandedRepos.contains(repo.url);
                          final catColor = _getCategoryColor(repo.category);

                          // Search highlight check
                          final query = _searchQuery.trim().toLowerCase();
                          final matchingPlugins = query.isNotEmpty
                              ? repo.plugins.where((p) => p.toLowerCase().contains(query)).toList()
                              : <String>[];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141721),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isInstalled
                                    ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top row: Title + Category badge
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              repo.name,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                  decoration: BoxDecoration(
                                                    color: catColor.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(color: catColor.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(_getCategoryEmoji(repo.category), style: const TextStyle(fontSize: 11)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        repo.category,
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: FontWeight.w700,
                                                          color: catColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (repo.plugins.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withValues(alpha: 0.08),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      '${repo.plugins.length} Plugins',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w600,
                                                        color: Colors.white.withValues(alpha: 0.7),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Added status indicator
                                      if (isInstalled)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                                              SizedBox(width: 4),
                                              Text(
                                                'Added',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Direct Install Link Box
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0B0D13),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.link_rounded, size: 14, color: Colors.white38),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            repo.url,
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontSize: 11,
                                              color: Colors.white.withValues(alpha: 0.45),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: () {
                                            Clipboard.setData(ClipboardData(text: repo.url));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Copied link: ${repo.url}'),
                                                duration: const Duration(seconds: 2),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Icon(Icons.copy_rounded, size: 12, color: Colors.white70),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Matching search banner
                                  if (matchingPlugins.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C5CFF).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF9D84FF)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Contains: ${matchingPlugins.join(', ')}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF9D84FF),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  // Plugins expandable list
                                  if (repo.plugins.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isExpanded) {
                                            _expandedRepos.remove(repo.url);
                                          } else {
                                            _expandedRepos.add(repo.url);
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 3),
                                        child: Row(
                                          children: [
                                            Text(
                                              isExpanded ? 'Hide plugins' : 'View all ${repo.plugins.length} plugins',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF7C5CFF).withValues(alpha: 0.9),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                              isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                              size: 16,
                                              color: const Color(0xFF7C5CFF),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isExpanded) ...[
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: repo.plugins.map((plugin) {
                                          final isMatched = query.isNotEmpty && plugin.toLowerCase().contains(query);
                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isMatched
                                                  ? const Color(0xFF7C5CFF).withValues(alpha: 0.3)
                                                  : Colors.white.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isMatched
                                                    ? const Color(0xFF7C5CFF)
                                                    : Colors.white.withValues(alpha: 0.08),
                                              ),
                                            ),
                                            child: Text(
                                              plugin,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isMatched ? Colors.white : Colors.white70,
                                                fontWeight: isMatched ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ],

                                  const SizedBox(height: 14),

                                  // Actions row
                                  Row(
                                    children: [
                                      if (!isInstalled)
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: isAdding ? null : () => _addRepo(repo),
                                            icon: isAdding
                                                ? const SizedBox(
                                                    width: 14,
                                                    height: 14,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                  )
                                                : const Icon(Icons.add_circle_outline_rounded, size: 16),
                                            label: Text(
                                              isAdding ? 'Adding Repository...' : 'Install Repository',
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF7C5CFF),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 10),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          ),
                                        )
                                      else ...[
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _installAllPlugins(repo.url),
                                            icon: const Icon(Icons.download_for_offline_rounded, size: 16),
                                            label: const Text(
                                              'Install All Plugins',
                                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF10B981),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 9),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            CloudStreamRepoModal.show(context);
                                          },
                                          icon: const Icon(Icons.manage_search_rounded, size: 16),
                                          label: const Text('Browse', style: TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white70,
                                            side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
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
}
