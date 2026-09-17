import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/cloudstream/cloudstream_source.dart';
import '../../services/cloudstream/cloudstream_manager.dart';

class CloudStreamRepoModal extends StatefulWidget {
  const CloudStreamRepoModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CloudStreamRepoModal(),
    );
  }

  @override
  State<CloudStreamRepoModal> createState() => _CloudStreamRepoModalState();
}

class _CloudStreamRepoModalState extends State<CloudStreamRepoModal> {
  final _manager = CloudStreamManager.instance;
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _installingIds = {};

  bool _isLoading = true;
  List<CloudStreamSource> _plugins = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAvailable();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailable() async {
    setState(() => _isLoading = true);
    try {
      final list = await _manager.fetchAvailableExtensions();
      if (mounted) {
        setState(() {
          _plugins = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CloudStreamSource> get _filteredPlugins {
    if (_searchQuery.trim().isEmpty) return _plugins;
    final q = _searchQuery.trim().toLowerCase();
    return _plugins.where((p) {
      final nameMatch = p.name.toLowerCase().contains(q);
      final langMatch = (p.lang ?? '').toLowerCase().contains(q);
      return nameMatch || langMatch;
    }).toList();
  }

  bool _isInstalled(CloudStreamSource plugin) {
    return _manager.installedExtensions.any(
      (e) => e.name.toLowerCase() == plugin.name.toLowerCase() ||
             (plugin.internalName != null && e.internalName == plugin.internalName),
    );
  }

  Future<void> _install(CloudStreamSource plugin) async {
    final id = plugin.internalName ?? plugin.name;
    setState(() => _installingIds.add(id));

    try {
      await _manager.installExtension(plugin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${plugin.name} installed successfully!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        setState(() => _installingIds.remove(id));
      }
    }
  }

  Future<void> _uninstall(CloudStreamSource plugin) async {
    final id = plugin.internalName ?? plugin.name;
    setState(() => _installingIds.add(id));

    try {
      await _manager.uninstallExtension(plugin);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${plugin.name} uninstalled.'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        setState(() => _installingIds.remove(id));
      }
    }
  }

  Future<void> _installAll() async {
    final uninstalled = _filteredPlugins.where((p) => !_isInstalled(p)).toList();
    if (uninstalled.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All matching plugins are already installed!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final count = await _manager.installExtensions(uninstalled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully installed $count plugins!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() {});
    } catch (e) {
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

  Future<void> _confirmUninstallAllInRepo() async {
    final installedList = _filteredPlugins.where((p) => _isInstalled(p)).toList();
    if (installedList.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151822),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 22),
            const SizedBox(width: 8),
            Text('Remove ${installedList.length} Plugin${installedList.length > 1 ? 's' : ''}?'),
          ],
        ),
        content: Text(
          'Are you sure you want to uninstall all ${installedList.length} installed plugins from this list? Their downloaded files will be removed.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.white.withValues(alpha: 0.45))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Remove All (${installedList.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await _manager.uninstallExtensions(installedList);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully uninstalled ${installedList.length} plugins.'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPlugins;
    final uninstalledCount = filtered.where((p) => !_isInstalled(p)).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F121A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 30,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    final installedCount = filtered.where((p) => _isInstalled(p)).length;

                    Widget removeAllBtn(bool fullWidth) => ValueListenableBuilder<bool>(
                          valueListenable: _manager.isBusy,
                          builder: (context, busy, _) {
                            return OutlinedButton.icon(
                              onPressed: busy ? null : _confirmUninstallAllInRepo,
                              icon: const Icon(Icons.delete_sweep_rounded, size: 14, color: Color(0xFFEF4444)),
                              label: Text(
                                'Remove All ($installedCount)',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.08),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          },
                        );

                    Widget installAllBtn(bool fullWidth) => ValueListenableBuilder<bool>(
                          valueListenable: _manager.isBusy,
                          builder: (context, busy, _) {
                            return ElevatedButton.icon(
                              onPressed: busy ? null : _installAll,
                              icon: const Icon(Icons.download_rounded, size: 14),
                              label: Text(
                                'Install All ($uninstalledCount)',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C5CFF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                visualDensity: VisualDensity.compact,
                              ),
                            );
                          },
                        );

                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Available Plugins',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          if (installedCount > 0 || uninstalledCount > 0) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (installedCount > 0)
                                  Expanded(child: removeAllBtn(true)),
                                if (installedCount > 0 && uninstalledCount > 0)
                                  const SizedBox(width: 8),
                                if (uninstalledCount > 0)
                                  Expanded(child: installAllBtn(true)),
                              ],
                            ),
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        const Text(
                          'Available CloudStream Plugins',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        if (installedCount > 0) ...[
                          removeAllBtn(false),
                          const SizedBox(width: 8),
                        ],
                        if (uninstalledCount > 0) ...[
                          installAllBtn(false),
                          const SizedBox(width: 8),
                        ],
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Progress bar if busy
              ValueListenableBuilder<bool>(
                valueListenable: _manager.isBusy,
                builder: (context, busy, _) {
                  if (!busy) return const SizedBox.shrink();
                  return ValueListenableBuilder<String>(
                    valueListenable: _manager.busyMessage,
                    builder: (context, msg, _) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C5CFF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF7C5CFF).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C5CFF)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                msg,
                                style: const TextStyle(fontSize: 12, color: Color(0xFFB4A0FF)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),

              // Search box
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white),
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search plugins (e.g. Sflix, SuperStream)...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF161A24),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // Plugins list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF7C5CFF)))
                    : filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'No plugins found in added repositories.\nPlease add a CloudStream repository URL first.'
                                    : 'No plugins matching "$_searchQuery"',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.white.withValues(alpha: 0.4),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final plugin = filtered[idx];
                              final installed = _isInstalled(plugin);
                              final id = plugin.internalName ?? plugin.name;
                              final isProcessing = _installingIds.contains(id);

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161A24),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: installed
                                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Plugin logo
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 40,
                                        height: 40,
                                        child: plugin.iconUrl != null && plugin.iconUrl!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: plugin.iconUrl!,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => const Icon(Icons.extension_rounded, color: Colors.white54),
                                              )
                                            : const Icon(Icons.extension_rounded, color: Colors.white54),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  plugin.name,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (plugin.isNsfw) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    '18+',
                                                    style: TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF7C5CFF).withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  plugin.effectiveLanguage.toUpperCase(),
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF7C5CFF),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'v${plugin.version ?? "1.0.0"}',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: Colors.white.withValues(alpha: 0.35),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Install / Installed button
                                    if (isProcessing)
                                      const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7C5CFF)),
                                      )
                                    else if (installed)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_rounded, size: 13, color: Color(0xFF10B981)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Installed',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 2),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                            onPressed: () => _uninstall(plugin),
                                            tooltip: 'Uninstall',
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.all(6),
                                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          ),
                                        ],
                                      )
                                    else
                                      ElevatedButton(
                                        onPressed: () => _install(plugin),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7C5CFF),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        child: const Text(
                                          'Install',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
