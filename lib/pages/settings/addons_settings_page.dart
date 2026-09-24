import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/addon/addon.dart';
import '../../models/cloudstream/cloudstream_repo.dart';
import '../../models/cloudstream/cloudstream_source.dart';
import '../../services/addon/addon_manager.dart';
import '../../services/storage/app_image_cache.dart';
import '../../services/cloudstream/cloudstream_manager.dart';
import '../../services/cloudstream/runtime/cloudstream_downloader.dart';
import 'cloudstream_marketplace_modal.dart';
import 'cloudstream_repo_modal.dart';
import '../../services/theme/app_theme_service.dart';

class AddonsSettingsPage extends StatefulWidget {
  const AddonsSettingsPage({super.key});

  @override
  State<AddonsSettingsPage> createState() => _AddonsSettingsPageState();
}

class _AddonsSettingsPageState extends State<AddonsSettingsPage> {
  final _manager = AddonManager.instance;
  final _csManager = CloudStreamManager.instance;
  final _csDownloader = CloudStreamDownloader.instance;

  int _selectedTabIndex = 0; // 0: Stremio Addons, 1: CloudStream Extensions
  bool _isAdding = false;
  bool _isAddingCsRepo = false;
  bool _csRuntimeReady = false;
  final Set<String> _selectedCsExtensionKeys = {};

  @override
  void initState() {
    super.initState();
    _manager.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _csManager.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _checkCsRuntime();
    _csDownloader.isReady.addListener(_onDownloaderChanged);
    _csDownloader.isDownloading.addListener(_onDownloaderChanged);
    _csDownloader.status.addListener(_onDownloaderChanged);
    _csDownloader.progress.addListener(_onDownloaderChanged);
  }

  @override
  void dispose() {
    _csDownloader.isReady.removeListener(_onDownloaderChanged);
    _csDownloader.isDownloading.removeListener(_onDownloaderChanged);
    _csDownloader.status.removeListener(_onDownloaderChanged);
    _csDownloader.progress.removeListener(_onDownloaderChanged);
    super.dispose();
  }

  void _onDownloaderChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkCsRuntime() async {
    final ready = await _csDownloader.checkIsReady();
    if (mounted) {
      setState(() => _csRuntimeReady = ready);
    }
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
                    borderSide: BorderSide(color: AppThemeService.currentPalette.value.primaryColor),
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
                backgroundColor: AppThemeService.currentPalette.value.primaryColor,
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

  Future<void> _addCsRepo() async {
    final url = await _showAddCsRepoDialog();
    if (url == null || url.trim().isEmpty) return;

    setState(() => _isAddingCsRepo = true);
    try {
      await _csManager.addRepo(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Repository added successfully!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF10B981),
        ),
      );

      final shouldInstall = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF151822),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Install Repository Plugins?'),
            content: const Text(
              'Would you like to install all plugins from this repository now so their streaming sources become available immediately on the watch screen?',
              style: TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Browse Later', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Install All Now', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );

      if (shouldInstall == true) {
        await _installAllFromRepo(url);
      }
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
      if (mounted) setState(() => _isAddingCsRepo = false);
    }
  }

  Future<void> _installAllFromRepo(String repoUrl) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151822),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Installing Plugins', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: _csManager.busyMessage,
                builder: (context, msg, _) => Text(
                  msg.isEmpty ? 'Preparing runtime...' : msg,
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
      final count = await _csManager.installAllFromRepo(repoUrl);
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully installed $count plugins from repository!'),
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

  Future<String?> _showAddCsRepoDialog() {
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
            'Add CloudStream Repository',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste the repository URL (supports cloudstreamrepo://, repo.json, or plugins.json).',
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
                  hintText: 'cloudstreamrepo://.../repo.json or plugins.json',
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
                    borderSide: BorderSide(color: AppThemeService.currentPalette.value.primaryColor),
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
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                CloudStreamMarketplaceModal.show(context);
              },
              icon: Icon(Icons.hub_rounded, size: 16, color: AppThemeService.currentPalette.value.primaryColor),
              label: Text('Browse Marketplace', style: TextStyle(color: AppThemeService.currentPalette.value.primaryColor, fontWeight: FontWeight.bold, fontSize: 12.5)),
            ),
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
                backgroundColor: AppThemeService.currentPalette.value.primaryColor,
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
                'Add Repository',
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

  void _confirmRemoveCsExtension(CloudStreamSource ext) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Remove ${ext.name}?'),
          content: Text(
            'This CloudStream extension will be uninstalled.',
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
                await _csManager.uninstallExtension(ext);
                if (mounted) setState(() {});
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

  void _confirmRemoveSelectedCsExtensions(List<CloudStreamSource> installed) {
    final toRemove = installed.where((e) => _selectedCsExtensionKeys.contains(e.internalName ?? e.name)).toList();
    if (toRemove.isEmpty) return;

    final count = toRemove.length;
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 22),
              const SizedBox(width: 10),
              Text('Remove $count Plugin${count > 1 ? 's' : ''}?'),
            ],
          ),
          content: Text(
            count == installed.length
                ? 'Are you sure you want to remove all $count installed CloudStream plugins? All downloaded plugin files (.jar/.cs3) will be deleted.'
                : 'Are you sure you want to remove the $count selected CloudStream plugins? Their downloaded files will be deleted from your device.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogCtx);
                await _csManager.uninstallExtensions(toRemove);
                if (!mounted) return;
                setState(() {
                  _selectedCsExtensionKeys.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text('Successfully removed $count plugin${count > 1 ? 's' : ''}.'),
                      ],
                    ),
                    backgroundColor: const Color(0xFFEF4444),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Remove ($count)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemoveCsRepo(CloudStreamRepo repo) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF151822),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Remove ${repo.name}?'),
          content: Text(
            'Plugins from this repository will not be deleted, but repository updates will no longer be fetched.',
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
                await _csManager.removeRepo(repo.url);
                if (mounted) setState(() {});
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
    final csExtensions = _csManager.installedExtensions;

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
          'Addons & Extensions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Segmented Tab Selector
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        title: 'Stremio Addons',
                        icon: Icons.extension_rounded,
                        count: addons.length,
                        isSelected: _selectedTabIndex == 0,
                        onTap: () => setState(() => _selectedTabIndex = 0),
                      ),
                    ),
                    Expanded(
                      child: _TabButton(
                        title: 'CloudStream',
                        icon: Icons.cloud_download_rounded,
                        count: csExtensions.length,
                        isSelected: _selectedTabIndex == 1,
                        onTap: () => setState(() => _selectedTabIndex = 1),
                      ),
                    ),
                  ],
                ),
              ),

              if (_selectedTabIndex == 0)
                _buildStremioTab(addons)
              else
                _buildCloudStreamTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStremioTab(List<InstalledAddon> addons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
            Expanded(
              child: Text(
                'INSTALLED PROVIDERS & ADDONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.35),
                  letterSpacing: 1.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${addons.length} Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppThemeService.currentPalette.value.primaryColor,
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
    );
  }

  Widget _buildCloudStreamTab() {
    final installed = _csManager.installedExtensions;
    final repos = _csManager.repos;
    final isReady = _csRuntimeReady || _csDownloader.isReady.value;
    final isDownloading = _csDownloader.isDownloading.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'CloudStream (.cs3) extensions provide stream providers directly from popular media sites. Extensions run locally in a sandboxed sidecar or native ART engine.',
            style: TextStyle(
              fontSize: 13.5,
              color: Colors.white.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ),

        // Runtime Status Card
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF12151E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isReady
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 500;
                  final statusContent = Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isReady
                              ? const Color(0xFF10B981).withValues(alpha: 0.15)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isReady ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                          color: isReady ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isReady ? 'CloudStream Engine Ready' : 'Runtime Setup Required',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isReady
                                  ? 'Native engine active and listening for queries.'
                                  : (isDownloading
                                      ? (_csDownloader.status.value.isNotEmpty
                                          ? _csDownloader.status.value
                                          : 'Downloading runtime components...')
                                      : (Platform.isAndroid
                                          ? 'Requires runtime host to execute .cs3 bytecode.'
                                          : 'Requires sidecar runtime to execute .cs3 bytecode.')),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isReady && !isDownloading && !isCompact) ...[
                        const SizedBox(width: 12),
                        _buildSetupEngineButton(),
                      ],
                    ],
                  );

                  if (isCompact && !isReady && !isDownloading) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        statusContent,
                        const SizedBox(height: 12),
                        _buildSetupEngineButton(),
                      ],
                    );
                  }
                  return statusContent;
                },
              ),
              if (isDownloading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _csDownloader.progress.value > 0 ? _csDownloader.progress.value : null,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    color: AppThemeService.currentPalette.value.primaryColor,
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),

        // Repository Marketplace Banner Card
        GestureDetector(
          onTap: () async {
            await CloudStreamMarketplaceModal.show(context);
            if (mounted) setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.22),
                  const Color(0xFF06B6D4).withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppThemeService.currentPalette.value.primaryColor, const Color(0xFF6366F1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.hub_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
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
                            'Repository Marketplace',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              '45+ Repos',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse curated Turkish, 3rabi, English, Hindi & global repos with direct install links.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),

        // Action Buttons (Responsive Row / Column)
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 520;

            final browseBtn = GestureDetector(
              onTap: () async {
                await CloudStreamRepoModal.show(context);
                if (mounted) setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [AppThemeService.currentPalette.value.primaryColor, const Color(0xFF6366F1)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Browse Available Plugins',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );

            final addRepoBtn = GestureDetector(
              onTap: _isAddingCsRepo ? null : _addCsRepo,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.3),
                  ),
                  color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.06),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isAddingCsRepo)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppThemeService.currentPalette.value.primaryColor),
                      )
                    else
                      Icon(Icons.add_link_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Add Repository',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppThemeService.currentPalette.value.primaryColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (isNarrow) {
              return Column(
                children: [
                  browseBtn,
                  const SizedBox(height: 10),
                  addRepoBtn,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: browseBtn),
                const SizedBox(width: 12),
                Expanded(child: addRepoBtn),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        // Section: Installed Extensions (Responsive Header)
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 560;

            Widget selectAllBtn() {
              final allKeys = installed.map((e) => e.internalName ?? e.name).toSet();
              final allSelected = allKeys.isNotEmpty && allKeys.every(_selectedCsExtensionKeys.contains);
              final anySelected = _selectedCsExtensionKeys.isNotEmpty;

              return TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (allSelected || anySelected) {
                      _selectedCsExtensionKeys.clear();
                    } else {
                      _selectedCsExtensionKeys.addAll(allKeys);
                    }
                  });
                },
                icon: Icon(
                  allSelected
                      ? Icons.check_box_rounded
                      : (anySelected
                          ? Icons.indeterminate_check_box_rounded
                          : Icons.check_box_outline_blank_rounded),
                  size: 16,
                  color: anySelected ? AppThemeService.currentPalette.value.primaryColor : Colors.white60,
                ),
                label: Text(
                  allSelected ? 'Deselect All' : (anySelected ? 'Deselect All' : 'Select All'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: anySelected ? AppThemeService.currentPalette.value.primaryColor : Colors.white70,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: anySelected
                      ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.05),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }

            Widget removeSelectedBtn() {
              return ElevatedButton.icon(
                onPressed: () => _confirmRemoveSelectedCsExtensions(installed),
                icon: const Icon(Icons.delete_sweep_rounded, size: 14),
                label: Text(
                  'Remove (${_selectedCsExtensionKeys.length})',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  visualDensity: VisualDensity.compact,
                  elevation: 0,
                ),
              );
            }

            final totalBadge = Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${installed.length} Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppThemeService.currentPalette.value.primaryColor,
                ),
              ),
            );

            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'INSTALLED EXTENSIONS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.35),
                            letterSpacing: 1.1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      totalBadge,
                    ],
                  ),
                  if (installed.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        selectAllBtn(),
                        if (_selectedCsExtensionKeys.isNotEmpty) removeSelectedBtn(),
                      ],
                    ),
                  ],
                ],
              );
            }

            return Row(
              children: [
                Text(
                  'INSTALLED CLOUDSTREAM EXTENSIONS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.35),
                    letterSpacing: 1.1,
                  ),
                ),
                const Spacer(),
                if (installed.isNotEmpty) ...[
                  selectAllBtn(),
                  const SizedBox(width: 8),
                  if (_selectedCsExtensionKeys.isNotEmpty) ...[
                    removeSelectedBtn(),
                    const SizedBox(width: 8),
                  ],
                ],
                totalBadge,
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        if (installed.isEmpty)
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
                  'No Extensions Installed',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  'Click "Browse Available Plugins" to find and install extensions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.4)),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: installed.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final ext = installed[index];
              final key = ext.internalName ?? ext.name;
              final isSelected = _selectedCsExtensionKeys.contains(key);
              return _CloudStreamCard(
                source: ext,
                isSelected: isSelected,
                onSelectToggle: () {
                  setState(() {
                    if (isSelected) {
                      _selectedCsExtensionKeys.remove(key);
                    } else {
                      _selectedCsExtensionKeys.add(key);
                    }
                  });
                },
                onToggle: (val) async {
                  await _csManager.toggleExtension(ext.internalName ?? ext.name, val);
                  setState(() {});
                },
                onRemove: () => _confirmRemoveCsExtension(ext),
              );
            },
          ),

        const SizedBox(height: 28),

        // Section: Added Repositories
        Row(
          children: [
            Text(
              'REPOSITORIES',
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
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${repos.length} Repos',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (repos.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF12151E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(Icons.link_off_rounded, color: Colors.white.withValues(alpha: 0.3), size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'No custom repositories added. Click "Add Repository" to subscribe to a CloudStream repository.',
                    style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.45)),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: repos.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final repo = repos[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_copy_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            repo.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            repo.url,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, size: 20),
                      color: AppThemeService.currentPalette.value.primaryColor,
                      splashRadius: 18,
                      tooltip: 'Install all plugins from this repository',
                      onPressed: () => _installAllFromRepo(repo.url),
                    ),
                    IconButton(
                      icon: const Icon(Icons.storefront_rounded, size: 19),
                      color: Colors.white70,
                      splashRadius: 18,
                      tooltip: 'Browse repository plugins',
                      onPressed: () async {
                        await CloudStreamRepoModal.show(context);
                        if (mounted) setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: Colors.white38,
                      splashRadius: 18,
                      tooltip: 'Remove repository',
                      onPressed: () => _confirmRemoveCsRepo(repo),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSetupEngineButton() {
    return ElevatedButton.icon(
      onPressed: () async {
        try {
          await _csDownloader.setupRuntime();
          await _checkCsRuntime();
          await _csManager.seedDefaultRepoIfEligible();
          if (mounted) setState(() {});
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Runtime setup error: $e'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      icon: const Icon(Icons.download_rounded, size: 16),
      label: const Text('Setup Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppThemeService.currentPalette.value.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
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
        ? AppThemeService.currentPalette.value.primaryColor
        : (isHttp ? const Color(0xFF10B981) : AppThemeService.currentPalette.value.primaryColor);

    final subtitleText = isP2p
        ? 'Built-in TorrServer P2P streaming engine'
        : (isHttp
            ? 'Built-in multi-source fast HTTP scrapers'
            : (m.supportsSubtitles && m.catalogs.isEmpty
                ? 'v${m.version}  ·  Subtitles Provider'
                : 'v${m.version}  ·  ${m.catalogs.length} catalog${m.catalogs.length == 1 ? '' : 's'}${m.supportsSubtitles ? '  ·  Subtitles' : ''}'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 560;

        Widget dragHandle() => ReorderableDragStartListener(
              index: index,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.drag_indicator_rounded,
                    color: Colors.white38,
                    size: 19,
                  ),
                ),
              ),
            );

        Widget priorityBadge() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: providerColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: providerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: providerColor,
                ),
              ),
            );

        Widget addonIcon() => Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(3.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: providerColor.withValues(alpha: 0.14),
              ),
              child: isBuiltIn
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/icon_small.png',
                        width: 26,
                        height: 26,
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
                            width: 26,
                            height: 26,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => Icon(
                              Icons.extension_rounded,
                              color: providerColor,
                              size: 19,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.extension_rounded,
                          color: providerColor,
                          size: 19,
                        )),
            );

        Widget upDownButtons() => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
                  color: onMoveUp != null ? Colors.white70 : Colors.white24,
                  onPressed: onMoveUp,
                  tooltip: 'Move up in priority',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
                  color: onMoveDown != null ? Colors.white70 : Colors.white24,
                  onPressed: onMoveDown,
                  tooltip: 'Move down in priority',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            );

        Widget switchWidget() => Switch.adaptive(
              value: addon.enabled,
              onChanged: onToggle,
              activeColor: providerColor,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );

        Widget builtInTag() => Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: providerColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                isP2p ? 'BUILT-IN TORRENT' : 'BUILT-IN HTTP',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: providerColor,
                  letterSpacing: 0.4,
                ),
              ),
            );

        Widget removeButton() => IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 19),
              color: Colors.red.withValues(alpha: 0.6),
              onPressed: onRemove,
              tooltip: 'Remove addon',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              visualDensity: VisualDensity.compact,
            );

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
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
              if (isMobile) ...[
                // Mobile Top Row: Drag + Priority + Icon + Title/Badge + Switch
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    dragHandle(),
                    priorityBadge(),
                    addonIcon(),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isBuiltIn) ...[
                            const SizedBox(height: 3),
                            builtInTag(),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    switchWidget(),
                  ],
                ),
                // Mobile Subtitle: Full width of the card, never squished
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2),
                  child: Text(
                    subtitleText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ] else ...[
                // Desktop Header Row: Everything inline
                Row(
                  children: [
                    dragHandle(),
                    priorityBadge(),
                    addonIcon(),
                    const SizedBox(width: 12),
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
                                builtInTag(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.4),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    upDownButtons(),
                    const SizedBox(width: 4),
                    switchWidget(),
                  ],
                ),
              ],

              // Description
              if (m.description != null && m.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  m.description!,
                  maxLines: 3,
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
                const SizedBox(height: 12),
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

              // Bottom Row: Type badges + (on mobile: Quick Move) + Remove
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
                  if (isMobile) ...[
                    const SizedBox(width: 8),
                    upDownButtons(),
                  ],
                  if (!isBuiltIn) ...[
                    const SizedBox(width: 6),
                    removeButton(),
                  ],
                ],
              ),
            ],
          ),
        );
      },
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
  final Color? activeColor;
  final bool showStateIcon;
  final VoidCallback onTap;

  const _FeatureToggleChip({
    required this.icon,
    required this.label,
    this.count,
    required this.isEnabled,
    this.activeColor,
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
    // A default parameter value has to be a compile-time constant, so the
    // palette accent cannot be one; it is resolved here instead.
    final activeColor =
        widget.activeColor ?? AppThemeService.currentPalette.value.primaryColor;
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
            color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.25),
          ),
          color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppThemeService.currentPalette.value.primaryColor,
                ),
              )
            else
              Icon(Icons.add_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 22),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'Installing...' : 'Add Addon',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppThemeService.currentPalette.value.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented Tab Button
// ─────────────────────────────────────────────────────────────────────────────

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.20)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.40)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppThemeService.currentPalette.value.primaryColor : Colors.white54,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : Colors.white60,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppThemeService.currentPalette.value.primaryColor
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CloudStream Extension Card
// ─────────────────────────────────────────────────────────────────────────────

class _CloudStreamCard extends StatelessWidget {
  final CloudStreamSource source;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;
  final bool isSelected;
  final VoidCallback onSelectToggle;

  const _CloudStreamCard({
    required this.source,
    required this.onToggle,
    required this.onRemove,
    required this.isSelected,
    required this.onSelectToggle,
  });

  @override
  Widget build(BuildContext context) {
    final hasIcon = source.iconUrl != null && source.iconUrl!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected
            ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.08)
            : const Color(0xFF12151E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.6)
              : (source.enabled
                  ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Checkmark Selection Button
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelectToggle,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppThemeService.currentPalette.value.primaryColor
                      : Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: isSelected
                        ? AppThemeService.currentPalette.value.primaryColor
                        : Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: Colors.white,
                      )
                    : null,
              ),
            ),
          ),

          // Icon
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 42,
              height: 42,
              color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.12),
              child: hasIcon
                  ? CachedNetworkImage(
                      imageUrl: source.iconUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(
                        Icons.cloud_rounded,
                        color: AppThemeService.currentPalette.value.primaryColor,
                        size: 22,
                      ),
                    )
                  : Icon(
                      Icons.cloud_rounded,
                      color: AppThemeService.currentPalette.value.primaryColor,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Details (Tap details area also toggles selection!)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSelectToggle,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          source.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? const Color(0xFFDDD6FE) : Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (source.lang != null && source.lang!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            source.lang!.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                      if (source.version != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          'v${source.version}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    source.description ?? 'CloudStream scraping & streaming provider',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Switch
          Switch(
            value: source.enabled,
            activeColor: AppThemeService.currentPalette.value.primaryColor,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onToggle,
          ),

          // Delete
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: Colors.white38,
            splashRadius: 18,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

