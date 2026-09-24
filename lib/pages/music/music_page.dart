import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/music/music_track.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/music/music_download_service.dart';
import '../../services/music/music_library_service.dart';
import '../../services/music/music_player_controller.dart';
import '../../services/music/music_service.dart';
import '../../services/music/music_settings.dart';
import '../../widgets/common/animated_ambient_background.dart';
import '../../widgets/common/focusable_card.dart';
import '../../widgets/common/performance_liquid_lens.dart';
import '../../widgets/common/slider_arrow.dart';
import '../../widgets/music/music_interactive_physics_button.dart';
import '../../widgets/music/music_waveform_seekbar.dart';
import '../settings/appearance/music_player_studio_page.dart';
import '../settings/appearance/music_settings_page.dart';
import '../settings/settings_page.dart';
import '../../utils/navigation/route_transitions.dart';
import '../../services/storage/app_image_cache.dart';

class MusicPage extends StatefulWidget {
  const MusicPage({super.key});

  @override
  State<MusicPage> createState() => _MusicPageState();
}

class _MusicPageState extends State<MusicPage> {
  final MusicService _musicService = MusicService.instance;
  final MusicPlayerController _playerController = MusicPlayerController.instance;
  final MusicLibraryService _libraryService = MusicLibraryService.instance;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  String _activeTab = 'Home'; // 'Home', 'Search', 'Browse', 'Radio', 'Library'

  Map<String, List<MusicTrack>> _sections = {};
  List<MusicArtist> _trendingArtists = [];
  List<MusicAlbum> _newReleases = [];
  List<MusicPlaylist> _curatedPlaylists = [];
  MusicTrack? _heroTrack;

  MusicSearchData _searchData = MusicSearchData.empty;
  MusicArtistDetails? _activeArtistModal;
  MusicAlbumDetails? _activeAlbumModal;
  MusicPlaylistDetails? _activeCuratedPlaylistModal;
  UserPlaylist? _activeUserPlaylistModal;

  bool _isLoading = true;
  bool _isSearching = false;
  bool _hasSearched = false;
  String _activeQuery = '';
  String _selectedFilter = 'All';
  Timer? _debounceTimer;

  bool _isPlayerExpanded = false;
  bool _showQueueDrawer = false;
  bool _showLyricsDrawer = false;
  bool _showShortcutsModal = false;
  bool _showDownloadsModal = false;
  String? _toastMessage;
  Timer? _toastTimer;

  @override
  void initState() {
    super.initState();
    _playerController.addListener(_onStateChanged);
    _libraryService.addListener(_onStateChanged);
    MusicDownloadService.instance.addListener(_onStateChanged);
    MusicSettings.changeNotifier.addListener(_onStateChanged);
    AppThemeService.currentPalette.addListener(_onStateChanged);
    _libraryService.init();
    MusicDownloadService.instance.init();
    _loadMusicData();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _toastTimer?.cancel();
    _playerController.removeListener(_onStateChanged);
    _libraryService.removeListener(_onStateChanged);
    MusicDownloadService.instance.removeListener(_onStateChanged);
    MusicSettings.changeNotifier.removeListener(_onStateChanged);
    AppThemeService.currentPalette.removeListener(_onStateChanged);
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _showToast(String message) {
    _toastTimer?.cancel();
    setState(() => _toastMessage = message);
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  Future<void> _loadMusicData() async {
    setState(() => _isLoading = true);

    try {
      final sectionsFuture = _musicService.fetchFeaturedSections();
      final artistsFuture = _musicService.fetchTrendingArtists();
      final releasesFuture = _musicService.fetchNewReleases();
      final playlistsFuture = _musicService.fetchCuratedPlaylists();

      final results = await Future.wait([
        sectionsFuture,
        artistsFuture,
        releasesFuture,
        playlistsFuture,
      ]);

      final sections = results[0] as Map<String, List<MusicTrack>>;
      final artists = results[1] as List<MusicArtist>;
      final releases = results[2] as List<MusicAlbum>;
      final playlists = results[3] as List<MusicPlaylist>;

      MusicTrack? hero;
      if (sections.isNotEmpty && sections.values.first.isNotEmpty) {
        hero = sections.values.first.first;
      }

      if (mounted) {
        setState(() {
          _sections = sections;
          _trendingArtists = artists;
          _newReleases = releases;
          _curatedPlaylists = playlists;
          _heroTrack = hero;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading music data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _searchData = MusicSearchData.empty;
        _activeQuery = '';
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isSearching = true;
        _activeQuery = trimmed;
        if (_activeTab != 'Search') _activeTab = 'Search';
      });

      final results = await _musicService.searchFull(trimmed);

      if (mounted) {
        setState(() {
          _searchData = results;
          _isSearching = false;
          _hasSearched = true;
        });
      }
    });
  }

  void _onGenreTap(String query) {
    _searchController.text = query;
    _onSearchChanged(query);
  }

  Future<void> _openArtistModal(String artistId) async {
    _showToast('Loading artist details...');
    final details = await _musicService.fetchArtistDetails(artistId);
    if (details != null && mounted) {
      setState(() {
        _activeArtistModal = details;
      });
    }
  }

  Future<void> _openAlbumModal(String albumId) async {
    _showToast('Loading album...');
    final details = await _musicService.fetchAlbumDetails(albumId);
    if (details != null && mounted) {
      setState(() {
        _activeAlbumModal = details;
      });
    }
  }

  Future<void> _openCuratedPlaylistModal(String playlistId) async {
    _showToast('Loading playlist...');
    final details = await _musicService.fetchPlaylistDetails(playlistId);
    if (details != null && mounted) {
      setState(() {
        _activeCuratedPlaylistModal = details;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (_searchFocusNode.hasFocus) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      _playerController.togglePlayPause();
    } else if (key == LogicalKeyboardKey.keyJ) {
      final newPos = _playerController.position - const Duration(seconds: 5);
      _playerController.seekTo(newPos.inSeconds < 0 ? Duration.zero : newPos);
      _showToast('Seek -5s');
    } else if (key == LogicalKeyboardKey.keyL) {
      final newPos = _playerController.position + const Duration(seconds: 5);
      _playerController.seekTo(newPos);
      _showToast('Seek +5s');
    } else if (key == LogicalKeyboardKey.keyM) {
      _playerController.setVolume(_playerController.volume > 0 ? 0.0 : 1.0);
      _showToast(_playerController.volume == 0 ? 'Muted' : 'Unmuted');
    } else if (key == LogicalKeyboardKey.keyQ) {
      setState(() => _showQueueDrawer = !_showQueueDrawer);
    } else if (key == LogicalKeyboardKey.keyF) {
      setState(() => _isPlayerExpanded = !_isPlayerExpanded);
    } else if (key == LogicalKeyboardKey.slash ||
        (HardwareKeyboard.instance.isShiftPressed &&
            key == LogicalKeyboardKey.slash)) {
      setState(() => _showShortcutsModal = !_showShortcutsModal);
    } else if (key == LogicalKeyboardKey.escape) {
      if (_isPlayerExpanded) {
        setState(() => _isPlayerExpanded = false);
      } else if (_showQueueDrawer) {
        setState(() => _showQueueDrawer = false);
      } else if (_showLyricsDrawer) {
        setState(() => _showLyricsDrawer = false);
      } else if (_showShortcutsModal) {
        setState(() => _showShortcutsModal = false);
      } else if (_showDownloadsModal) {
        setState(() => _showDownloadsModal = false);
      } else if (_activeArtistModal != null ||
          _activeAlbumModal != null ||
          _activeCuratedPlaylistModal != null ||
          _activeUserPlaylistModal != null) {
        setState(() {
          _activeArtistModal = null;
          _activeAlbumModal = null;
          _activeCuratedPlaylistModal = null;
          _activeUserPlaylistModal = null;
          _showDownloadsModal = false;
        });
      } else {
        Navigator.maybePop(context);
      }
    }
  }

  void _showCreatePlaylistDialog({MusicTrack? initialTrack}) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13151C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.3),
          ),
        ),
        title: Row(
          children: [
            Icon(
              Icons.playlist_add_rounded,
              color: AppThemeService.currentPalette.value.primaryColor,
              size: 26,
            ),
            const SizedBox(width: 10),
            const Text(
              'New Playlist',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (initialTrack != null) ...[
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: initialTrack.coverUrl,
                      cacheManager: AppImageCache.manager,
                      memCacheWidth: 120,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          initialTrack.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          initialTrack.artist,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter playlist title...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1B1E2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppThemeService.currentPalette.value.primaryColor),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeService.currentPalette.value.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final pl = await _libraryService.createPlaylist(name);
                if (initialTrack != null) {
                  await _libraryService.addTrackToPlaylist(pl.id, initialTrack);
                  _showToast('Added "${initialTrack.title}" to "$name"');
                } else {
                  _showToast('Created playlist "$name"');
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text(
              'Create',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistMenu(MusicTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final playlists = _libraryService.userPlaylists;
        return PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: track.coverUrl,
                        cacheManager: AppImageCache.manager,
                        memCacheWidth: 156,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            track.artist,
                            style: const TextStyle(
                              color: Color(0xFF9E9EA8),
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 10),

                // Quick Offline Download Action
                Builder(
                  builder: (context) {
                    final isDownloaded = MusicDownloadService.instance.isDownloaded(track.id);
                    final isQueued = MusicDownloadService.instance.isQueued(track.id);

                    return InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (isDownloaded) {
                          await MusicDownloadService.instance.deleteDownloadedTrack(track.id);
                          _showToast('Removed "${track.title}" from downloads');
                        } else if (!isQueued) {
                          MusicDownloadService.instance.queueTrack(track);
                          _showToast('Added "${track.title}" to download queue');
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDownloaded
                              ? const Color(0xFF00B0FF).withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDownloaded
                                ? const Color(0xFF00B0FF).withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isDownloaded
                                  ? Icons.download_done_rounded
                                  : (isQueued ? Icons.hourglass_top_rounded : Icons.download_rounded),
                              color: isDownloaded ? const Color(0xFF00E5FF) : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isDownloaded
                                    ? 'Downloaded Offline (Tap to Remove)'
                                    : (isQueued ? 'Downloading / Queued...' : 'Download Track Offline'),
                                style: TextStyle(
                                  color: isDownloaded ? const Color(0xFF00E5FF) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            if (isDownloaded)
                              const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'Save to Playlist',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showCreatePlaylistDialog(initialTrack: track);
                      },
                      icon: Icon(
                        Icons.add_rounded,
                        color: AppThemeService.currentPalette.value.primaryColor,
                        size: 18,
                      ),
                      label: Text(
                        'New Playlist',
                        style: TextStyle(
                          color: AppThemeService.currentPalette.value.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.playlist_add_rounded,
                            color: Colors.white38,
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No custom playlists yet',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showCreatePlaylistDialog(initialTrack: track);
                            },
                            child: const Text(
                              'Create First Playlist',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: playlists.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final pl = playlists[index];
                        final inPlaylist = pl.tracks.any((t) => t.id == track.id);
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          tileColor: const Color(0xFF1B1E2B),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.music_note_rounded,
                              color: AppThemeService.currentPalette.value.primaryColor,
                            ),
                          ),
                          title: Text(
                            pl.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${pl.tracks.length} tracks',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Icon(
                            inPlaylist
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_outline_rounded,
                            color: inPlaylist
                                ? const Color(0xFF00D294)
                                : Colors.white60,
                          ),
                          onTap: () async {
                            if (inPlaylist) {
                              await _libraryService.removeTrackFromPlaylist(
                                pl.id,
                                track.id,
                              );
                              _showToast('Removed from "${pl.title}"');
                            } else {
                              await _libraryService.addTrackToPlaylist(
                                pl.id,
                                track,
                              );
                              _showToast('Added to "${pl.title}"');
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= 900;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF080A0F),
        body: Stack(
          children: [
            // Dynamic Ambient Background Atmosphere
            if (MusicSettings.enableAmbientLights.value)
              const Positioned.fill(
                child: AnimatedAmbientBackground(),
              ),

            // Main App Shell Layout
            Row(
              children: [
                if (isDesktop)
                  _MusicSidebar(
                    activeTab: _activeTab,
                    onTabSelected: (tab) {
                      setState(() {
                        _activeTab = tab;
                        if (tab != 'Search') _hasSearched = false;
                      });
                    },
                    onShortcutsTap: () => setState(() => _showShortcutsModal = true),
                  ),

                // Main Page Content Area
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildTabContent(isDesktop),
                      ),

                      // Sticky Top Header (Search bar, status, settings)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _MusicTopHeader(
                          isDesktop: isDesktop,
                          searchController: _searchController,
                          searchFocusNode: _searchFocusNode,
                          isSearching: _isSearching,
                          onSearchChanged: _onSearchChanged,
                          onClearSearch: _clearSearch,
                          onSettingsTap: () {
                            Navigator.push(
                              context,
                              LiquidRevealRoute(
                                page: const SettingsPage(),
                                tapPosition: null,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Mobile Bottom Navigation Bar
            if (!isDesktop)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _MusicMobileBottomNav(
                  activeTab: _activeTab,
                  onTabSelected: (tab) {
                    setState(() {
                      _activeTab = tab;
                      if (tab != 'Search') _hasSearched = false;
                    });
                  },
                ),
              ),

            // Floating Mini-Player Bar
            if (_playerController.hasTrack && !_isPlayerExpanded)
              Positioned(
                left: isDesktop ? 260 : 12,
                right: 12,
                bottom: isDesktop ? 16 : (64.0 + MediaQuery.paddingOf(context).bottom + 10.0),
                child: _MusicBottomPlayerBar(
                  playerController: _playerController,
                  isSaved: _libraryService.isTrackLiked(
                    _playerController.currentTrack?.id ?? '',
                  ),
                  onToggleSave: () {
                    if (_playerController.currentTrack != null) {
                      _libraryService.toggleLikeTrack(_playerController.currentTrack!);
                    }
                  },
                  onExpandTap: () => setState(() => _isPlayerExpanded = true),
                  onQueueTap: () => setState(() => _showQueueDrawer = true),
                  onLyricsTap: () => setState(() => _showLyricsDrawer = true),
                  onAddToPlaylist: () {
                    if (_playerController.currentTrack != null) {
                      _showAddToPlaylistMenu(_playerController.currentTrack!);
                    }
                  },
                ),
              ),

            // Queue Drawer
            if (_showQueueDrawer)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: _MusicQueueDrawer(
                  onClose: () => setState(() => _showQueueDrawer = false),
                ),
              ),

            // Synced Lyrics Drawer
            if (_showLyricsDrawer && _playerController.hasTrack)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: _MusicLyricsDrawer(
                  track: _playerController.currentTrack!,
                  playerController: _playerController,
                  onClose: () => setState(() => _showLyricsDrawer = false),
                ),
              ),

            // Modals: Artist Detail
            if (_activeArtistModal != null)
              Positioned.fill(
                child: _MusicArtistDetailModal(
                  details: _activeArtistModal!,
                  onClose: () => setState(() => _activeArtistModal = null),
                  onPlayTrack: (t, queue) => _playerController.playTrack(t, playlistQueue: queue),
                  onAddToPlaylist: _showAddToPlaylistMenu,
                  onOpenAlbum: _openAlbumModal,
                ),
              ),

            // Modals: Album Detail
            if (_activeAlbumModal != null)
              Positioned.fill(
                child: _MusicAlbumDetailModal(
                  details: _activeAlbumModal!,
                  onClose: () => setState(() => _activeAlbumModal = null),
                  onPlayTrack: (t, queue) => _playerController.playTrack(t, playlistQueue: queue),
                  onAddToPlaylist: _showAddToPlaylistMenu,
                ),
              ),

            // Modals: Curated Playlist Detail
            if (_activeCuratedPlaylistModal != null)
              Positioned.fill(
                child: _MusicCuratedPlaylistDetailModal(
                  details: _activeCuratedPlaylistModal!,
                  onClose: () => setState(() => _activeCuratedPlaylistModal = null),
                  onPlayTrack: (t, queue) => _playerController.playTrack(t, playlistQueue: queue),
                  onAddToPlaylist: _showAddToPlaylistMenu,
                ),
              ),

            // Modals: User Playlist Detail
            if (_activeUserPlaylistModal != null)
              Positioned.fill(
                child: _MusicUserPlaylistDetailModal(
                  playlist: _activeUserPlaylistModal!,
                  onClose: () => setState(() => _activeUserPlaylistModal = null),
                  onPlayTrack: (t, queue) => _playerController.playTrack(t, playlistQueue: queue),
                  onRemoveTrack: (trackId) async {
                    await _libraryService.removeTrackFromPlaylist(_activeUserPlaylistModal!.id, trackId);
                    setState(() {
                      final updated = _libraryService.userPlaylists.firstWhere(
                        (p) => p.id == _activeUserPlaylistModal!.id,
                        orElse: () => _activeUserPlaylistModal!,
                      );
                      _activeUserPlaylistModal = updated;
                    });
                  },
                ),
              ),

            // Modals: Shortcuts
            if (_showShortcutsModal)
              Positioned.fill(
                child: _MusicShortcutsModal(
                  onClose: () => setState(() => _showShortcutsModal = false),
                ),
              ),

            // Modals: Downloaded Offline Tracks
            if (_showDownloadsModal)
              Positioned.fill(
                child: _MusicDownloadedTracksModal(
                  onClose: () => setState(() => _showDownloadsModal = false),
                  onPlayTrack: (t, queue) => _playerController.playTrack(t, playlistQueue: queue),
                  onAddToPlaylist: _showAddToPlaylistMenu,
                ),
              ),

            // Fullscreen Expanded Now-Playing Player
            if (_isPlayerExpanded && _playerController.hasTrack)
              Positioned.fill(
                child: _MusicExpandedPlayer(
                  playerController: _playerController,
                  isSaved: _libraryService.isTrackLiked(
                    _playerController.currentTrack?.id ?? '',
                  ),
                  onToggleSave: () {
                    if (_playerController.currentTrack != null) {
                      _libraryService.toggleLikeTrack(_playerController.currentTrack!);
                    }
                  },
                  onCollapse: () => setState(() => _isPlayerExpanded = false),
                  onQueueTap: () => setState(() => _showQueueDrawer = true),
                  onAddToPlaylist: () {
                    if (_playerController.currentTrack != null) {
                      _showAddToPlaylistMenu(_playerController.currentTrack!);
                    }
                  },
                ),
              ),

            // Temporary Notification Toast
            if (_toastMessage != null)
              Positioned(
                top: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppThemeService.currentPalette.value.primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _toastMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(bool isDesktop) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor),
      );
    }

    if (_activeTab == 'Search' || _hasSearched || _searchController.text.isNotEmpty) {
      return _buildSearchView();
    }
    if (_activeTab == 'Browse') return _buildBrowseView();
    if (_activeTab == 'Radio') return _buildRadioView();
    if (_activeTab == 'Library') return _buildLibraryView();

    final bottomPad = isDesktop ? 120.0 : 160.0;

    return RefreshIndicator(
      color: AppThemeService.currentPalette.value.primaryColor,
      backgroundColor: const Color(0xFF151822),
      onRefresh: _loadMusicData,
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.only(top: 75, bottom: bottomPad),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        children: [
          if (MusicSettings.enableSpotlight.value && _heroTrack != null)
            _MusicHeroBillboard(
              track: _heroTrack!,
              onPlayTap: () => _playerController.playTrack(
                _heroTrack!,
                playlistQueue: _sections.values.isNotEmpty ? _sections.values.first : null,
              ),
              onSaveTap: () {
                _libraryService.toggleLikeTrack(_heroTrack!);
                _showToast(
                  _libraryService.isTrackLiked(_heroTrack!.id)
                      ? 'Saved to Library'
                      : 'Removed from Library',
                );
              },
              onAddToPlaylistTap: () => _showAddToPlaylistMenu(_heroTrack!),
              isSaved: _libraryService.isTrackLiked(_heroTrack!.id),
            ),
          const SizedBox(height: 24),
          if (_trendingArtists.isNotEmpty)
            _MusicTrendingArtists(
              artists: _trendingArtists,
              onArtistTap: (artist) {
                if (artist.id.isNotEmpty) {
                  _openArtistModal(artist.id);
                } else {
                  _onGenreTap(artist.name);
                }
              },
            ),
          if (_newReleases.isNotEmpty)
            _MusicAlbumsRow(
              title: '💿 New Album Releases',
              albums: _newReleases,
              onAlbumTap: (album) => _openAlbumModal(album.id),
            ),
          if (_curatedPlaylists.isNotEmpty)
            _MusicPlaylistsRow(
              title: '🎧 Curated Charts & Mixes',
              playlists: _curatedPlaylists,
              onPlaylistTap: (pl) => _openCuratedPlaylistModal(pl.id),
            ),
          for (final entry in _sections.entries)
            _MusicCategorySlider(
              title: entry.key,
              tracks: entry.value,
              onAddToPlaylist: _showAddToPlaylistMenu,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchView() {
    final sizing = _MusicCardSizing.fromWidth(MediaQuery.sizeOf(context).width);

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterTab('All'),
              const SizedBox(width: 8),
              _filterTab('Tracks (${_searchData.tracks.length})'),
              const SizedBox(width: 8),
              _filterTab('Artists (${_searchData.artists.length})'),
              const SizedBox(width: 8),
              _filterTab('Albums (${_searchData.albums.length})'),
              const SizedBox(width: 8),
              _filterTab('Playlists (${_searchData.playlists.length})'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor),
            ),
          )
        else if (_searchData.tracks.isEmpty &&
            _searchData.artists.isEmpty &&
            _searchData.albums.isEmpty &&
            _searchData.playlists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off_rounded,
                    color: Colors.white38,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results for "$_activeQuery"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          if ((_selectedFilter == 'All' || _selectedFilter.startsWith('Tracks')) &&
              _searchData.tracks.isNotEmpty) ...[
            const Text(
              'Songs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchData.tracks.length.clamp(0, 15),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final track = _searchData.tracks[index];
                return _MusicTrackRow(
                  track: track,
                  isPlaying: _playerController.currentTrack?.id == track.id &&
                      _playerController.isPlaying,
                  isCurrent: _playerController.currentTrack?.id == track.id,
                  onTap: () => _playerController.playTrack(
                    track,
                    playlistQueue: _searchData.tracks,
                  ),
                  onMoreTap: () => _showAddToPlaylistMenu(track),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          if ((_selectedFilter == 'All' || _selectedFilter.startsWith('Artists')) &&
              _searchData.artists.isNotEmpty) ...[
            const Text(
              'Artists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 130,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _searchData.artists.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final artist = _searchData.artists[index];
                  return FocusableCard(
                    onTap: () => _openArtistModal(artist.id),
                    builder: (context, state) => AnimatedScale(
                      scale: state.highlighted ? 1.06 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      child: Column(
                        children: [
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: artist.pictureUrl,
                              cacheManager: AppImageCache.manager,
                              memCacheWidth: 240,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 90,
                            child: Text(
                              artist.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
          if ((_selectedFilter == 'All' || _selectedFilter.startsWith('Albums')) &&
              _searchData.albums.isNotEmpty) ...[
            const Text(
              'Albums',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (MediaQuery.sizeOf(context).width / sizing.cardWidth)
                    .floor()
                    .clamp(2, 6),
                mainAxisSpacing: 20,
                crossAxisSpacing: 16,
                childAspectRatio: sizing.cardWidth / sizing.totalHeight,
              ),
              itemCount: _searchData.albums.length.clamp(0, 12),
              itemBuilder: (context, index) {
                final album = _searchData.albums[index];
                return _MusicAlbumCard(
                  album: album,
                  onTap: () => _openAlbumModal(album.id),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
          if ((_selectedFilter == 'All' || _selectedFilter.startsWith('Playlists')) &&
              _searchData.playlists.isNotEmpty) ...[
            const Text(
              'Playlists',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (MediaQuery.sizeOf(context).width / sizing.cardWidth)
                    .floor()
                    .clamp(2, 6),
                mainAxisSpacing: 20,
                crossAxisSpacing: 16,
                childAspectRatio: sizing.cardWidth / sizing.totalHeight,
              ),
              itemCount: _searchData.playlists.length.clamp(0, 12),
              itemBuilder: (context, index) {
                final pl = _searchData.playlists[index];
                return _MusicPlaylistCard(
                  playlist: pl,
                  onTap: () => _openCuratedPlaylistModal(pl.id),
                );
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _filterTab(String label) {
    final isSelected = _selectedFilter == label ||
        (_selectedFilter == 'All' && label == 'All') ||
        (label.startsWith(_selectedFilter) && _selectedFilter != 'All');

    return FocusableCard(
      onTap: () {
        setState(() {
          if (label.startsWith('Tracks')) {
            _selectedFilter = 'Tracks';
          } else if (label.startsWith('Artists')) {
            _selectedFilter = 'Artists';
          } else if (label.startsWith('Albums')) {
            _selectedFilter = 'Albums';
          } else if (label.startsWith('Playlists')) {
            _selectedFilter = 'Playlists';
          } else {
            _selectedFilter = 'All';
          }
        });
      },
      builder: (context, state) => AnimatedScale(
        scale: state.highlighted ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppThemeService.currentPalette.value.primaryColor
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppThemeService.currentPalette.value.primaryColor
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseView() {
    final genres = [
      {'title': 'Pop Hits', 'color': const Color(0xFF7C5CFF), 'query': 'Pop Hits'},
      {'title': 'Hip-Hop & Rap', 'color': const Color(0xFF7850FF), 'query': 'Hip-Hop'},
      {'title': 'Electronic & EDM', 'color': const Color(0xFF00D294), 'query': 'EDM Dance'},
      {'title': 'Chill Lofi Beats', 'color': const Color(0xFF00D2EF), 'query': 'Chill Lofi'},
      {'title': 'Rock Classics', 'color': const Color(0xFFF99C00), 'query': 'Rock Classics'},
      {'title': 'R&B & Soul', 'color': const Color(0xFFE12AFB), 'query': 'R&B Soul'},
      {'title': 'Soundtracks & Gaming', 'color': const Color(0xFFFF6568), 'query': 'Soundtracks'},
      {'title': 'Heavy Metal', 'color': const Color(0xFFFB2C36), 'query': 'Heavy Metal'},
      {'title': 'Jazz & Blues', 'color': const Color(0xFF625FFF), 'query': 'Jazz Blues'},
      {'title': 'Classical Piano', 'color': const Color(0xFFFAC800), 'query': 'Classical Piano'},
    ];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        const Text(
          'Browse Moods & Genres',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.6,
          ),
          itemCount: genres.length,
          itemBuilder: (context, index) {
            final g = genres[index];
            final color = g['color'] as Color;
            return FocusableCard(
              onTap: () => _onGenreTap(g['query'] as String),
              builder: (context, state) => AnimatedScale(
                scale: state.highlighted ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: PerformanceLiquidLens(
                  style: PerformanceGlassStyles.menu,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color.withValues(alpha: 0.85),
                          color.withValues(alpha: 0.40),
                        ],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        g['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRadioView() {
    final radioGenres = [
      {'name': 'Pop Radio', 'color': const Color(0xFF7C5CFF), 'query': 'Pop Radio Hits'},
      {'name': 'Rap & Hip-Hop', 'color': const Color(0xFF7850FF), 'query': 'Hip Hop Radio'},
      {'name': 'Rock Mix', 'color': const Color(0xFFF99C00), 'query': 'Rock Radio'},
      {'name': 'Dance & Electro', 'color': const Color(0xFF00D294), 'query': 'Electro Radio'},
      {'name': 'R&B Station', 'color': const Color(0xFFE12AFB), 'query': 'R&B Radio'},
      {'name': 'Lofi & Ambient', 'color': const Color(0xFF00D2EF), 'query': 'Lofi Radio'},
      {'name': 'Heavy Metal Station', 'color': const Color(0xFFFB2C36), 'query': 'Metal Radio'},
      {'name': 'Jazz Club', 'color': const Color(0xFF625FFF), 'query': 'Jazz Radio'},
    ];

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        const Text(
          'Radio Stations & Live Streams',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Continuous music channels tuned to your mood.',
          style: TextStyle(color: Color(0xFF9E9EA8), fontSize: 14),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: radioGenres.length,
          itemBuilder: (context, index) {
            final station = radioGenres[index];
            final color = station['color'] as Color;
            return FocusableCard(
              onTap: () => _onGenreTap(station['query'] as String),
              builder: (context, state) => AnimatedScale(
                scale: state.highlighted ? 1.04 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: PerformanceLiquidLens(
                  style: PerformanceGlassStyles.menu,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: color.withValues(alpha: 0.20),
                      border: Border.all(color: color.withValues(alpha: 0.5)),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.radio_rounded, color: color, size: 28),
                        Text(
                          station['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLibraryView() {
    final liked = _libraryService.likedTracks;
    final playlists = _libraryService.userPlaylists;
    final recent = _libraryService.recentTracks;

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 150),
      children: [
        Row(
          children: [
            const Text(
              'Your Library',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
              ),
            ),
            const Spacer(),
            _MusicHoverable(
              scaleFactor: 1.05,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => _showCreatePlaylistDialog(),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text(
                  'New Playlist',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Liked Songs Banner
        FocusableCard(
          onTap: () {
            if (liked.isNotEmpty) {
              _playerController.playTrack(liked.first, playlistQueue: liked);
            } else {
              _showToast('No liked songs yet');
            }
          },
          builder: (context, state) => AnimatedScale(
            scale: state.highlighted ? 1.02 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: PerformanceLiquidLens(
              style: PerformanceGlassStyles.menu,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B36F5), Color(0xFF8F58FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF5B36F5).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Liked Songs',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${liked.length} favourite tracks',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (liked.isNotEmpty)
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Color(0xFF5B36F5),
                          size: 30,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Downloaded Songs Banner (Offline Music)
        Builder(
          builder: (context) {
            final downloaded = MusicDownloadService.instance.downloadedTracks;
            final queue = MusicDownloadService.instance.queue;
            final totalBytes = MusicDownloadService.instance.totalDownloadedSizeBytes;
            final sizeMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

            return FocusableCard(
              onTap: () {
                setState(() => _showDownloadsModal = true);
              },
              builder: (context, state) => AnimatedScale(
                scale: state.highlighted ? 1.02 : 1.0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: PerformanceLiquidLens(
                  style: PerformanceGlassStyles.menu,
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0083B0), Color(0xFF00B4DB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00B4DB).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.download_done_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Downloaded Songs',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (queue.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Queue (${queue.length})',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${downloaded.length} offline tracks • $sizeMb MB',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF0083B0),
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 28),

        // User Playlists Section
        if (playlists.isNotEmpty) ...[
          const Text(
            'Custom Playlists',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final pl = playlists[index];
              return FocusableCard(
                onTap: () => setState(() => _activeUserPlaylistModal = pl),
                builder: (context, state) => AnimatedScale(
                  scale: state.highlighted ? 1.04 : 1.0,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF13151F),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 70,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.queue_music_rounded,
                            color: AppThemeService.currentPalette.value.primaryColor,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          pl.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${pl.tracks.length} tracks',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
        ],

        // Recent History Section
        if (recent.isNotEmpty) ...[
          const Text(
            'Recently Played',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recent.length.clamp(0, 10),
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final track = recent[index];
              return _MusicTrackRow(
                track: track,
                isPlaying: _playerController.currentTrack?.id == track.id &&
                    _playerController.isPlaying,
                isCurrent: _playerController.currentTrack?.id == track.id,
                onTap: () => _playerController.playTrack(track, playlistQueue: recent),
                onMoreTap: () => _showAddToPlaylistMenu(track),
              );
            },
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FPS-Friendly Hover Container
// ─────────────────────────────────────────────────────────────────────────────

class _MusicHoverable extends StatefulWidget {
  final Widget child;
  final double scaleFactor;

  const _MusicHoverable({
    required this.child,
    this.scaleFactor = 1.04,
  });

  @override
  State<_MusicHoverable> createState() => _MusicHoverableState();
}

class _MusicHoverableState extends State<_MusicHoverable> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? widget.scaleFactor : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Horizontal Slider with Desktop Navigation Arrows
// ─────────────────────────────────────────────────────────────────────────────

class _MusicHorizontalScrollSection extends StatefulWidget {
  final String? title;
  final double height;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const _MusicHorizontalScrollSection({
    this.title,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<_MusicHorizontalScrollSection> createState() => _MusicHorizontalScrollSectionState();
}

class _MusicHorizontalScrollSectionState extends State<_MusicHorizontalScrollSection> {
  late final ScrollController _controller;
  bool _canScrollLeft = false;
  bool _canScrollRight = true;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
    _controller.addListener(_updateScrollButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollButtons();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateScrollButtons);
    _controller.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_controller.hasClients) return;
    final canLeft = _controller.position.pixels > 5;
    final canRight = _controller.position.pixels < _controller.position.maxScrollExtent - 5;
    if (canLeft != _canScrollLeft || canRight != _canScrollRight) {
      setState(() {
        _canScrollLeft = canLeft;
        _canScrollRight = canRight;
      });
    }
  }

  void _scroll(double multiplier) {
    if (!_controller.hasClients) return;
    final viewportWidth = _controller.position.viewportDimension;
    final scrollAmount = viewportWidth * 0.75 * multiplier;
    final target = (_controller.position.pixels + scrollAmount)
        .clamp(0.0, _controller.position.maxScrollExtent);

    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = _isDesktop(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              widget.title!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: widget.itemCount,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: widget.itemBuilder,
                ),

                // Desktop Left & Right Floating Arrows
                if (isDesktop) ...[
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    left: _canScrollLeft && _isHovered ? 8 : -60,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: SliderArrow(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => _scroll(-1),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    right: _canScrollRight && _isHovered ? 8 : -60,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: SliderArrow(
                        icon: Icons.arrow_forward_ios_rounded,
                        onTap: () => _scroll(1),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Components & Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _MusicSidebar extends StatelessWidget {
  final String activeTab;
  final Function(String) onTabSelected;
  final VoidCallback onShortcutsTap;

  const _MusicSidebar({
    required this.activeTab,
    required this.onTabSelected,
    required this.onShortcutsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E17),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                _MusicHoverable(
                  scaleFactor: 1.08,
                  child: IconButton(
                    tooltip: 'Back to Home (Esc)',
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      padding: const EdgeInsets.all(10),
                    ),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppThemeService.currentPalette.value.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'MUSIC',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          _sidebarActionItem(
            'Exit Music',
            Icons.logout_rounded,
            () => Navigator.maybePop(context),
          ),
          const SizedBox(height: 4),
          _sidebarItem('Home', Icons.home_rounded),
          _sidebarItem('Browse', Icons.explore_rounded),
          _sidebarItem('Radio', Icons.radio_rounded),
          _sidebarItem('Library', Icons.library_music_rounded),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'AUDIO SOURCE',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
          _sidebarAudioSourceSelector(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: onShortcutsTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.keyboard_rounded, color: Colors.white54, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Shortcuts ( ? )',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarAudioSourceSelector() {
    final player = MusicPlayerController.instance;
    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final isFlac = player.audioSource == MusicAudioSource.flac;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => player.setAudioSource(MusicAudioSource.flac),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isFlac ? const Color(0xFF00D2EF).withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: isFlac ? Border.all(color: const Color(0xFF00D2EF).withValues(alpha: 0.4)) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.diamond_rounded, size: 14, color: isFlac ? const Color(0xFF00D2EF) : Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            'FLAC',
                            style: TextStyle(
                              color: isFlac ? Colors.white : Colors.white60,
                              fontSize: 11,
                              fontWeight: isFlac ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: InkWell(
                    onTap: () => player.setAudioSource(MusicAudioSource.youtube),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !isFlac ? const Color(0xFFFF3366).withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: !isFlac ? Border.all(color: const Color(0xFFFF3366).withValues(alpha: 0.4)) : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_fill_rounded, size: 14, color: !isFlac ? const Color(0xFFFF3366) : Colors.white54),
                          const SizedBox(width: 4),
                          Text(
                            'YouTube',
                            style: TextStyle(
                              color: !isFlac ? Colors.white : Colors.white60,
                              fontSize: 11,
                              fontWeight: !isFlac ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sidebarActionItem(String label, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: _MusicHoverable(
        scaleFactor: 1.02,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF00D2EF),
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarItem(String label, IconData icon) {
    final isSelected = activeTab == label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: _MusicHoverable(
        scaleFactor: 1.02,
        child: InkWell(
          onTap: () => onTabSelected(label),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? AppThemeService.currentPalette.value.primaryColor : Colors.white60,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicTopHeader extends StatelessWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isSearching;
  final Function(String) onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onSettingsTap;

  const _MusicTopHeader({
    required this.isDesktop,
    required this.searchController,
    required this.searchFocusNode,
    required this.isSearching,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final screenW = MediaQuery.sizeOf(context).width;
    final isMobile = screenW < 600;
    final isVeryNarrow = screenW < 400;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.dock,
      child: Container(
        height: isDesktop ? 68.0 : (58.0 + topInset),
        padding: EdgeInsets.fromLTRB(
          isMobile ? 10 : 20,
          isDesktop ? 0 : topInset,
          isMobile ? 10 : 20,
          0,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF080A0F).withValues(alpha: 0.85),
          border: Border(
            bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
        child: Row(
          children: [
            _MusicHoverable(
              scaleFactor: 1.08,
              child: IconButton(
                tooltip: 'Back to Home (Esc)',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  padding: const EdgeInsets.all(8),
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF13151F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: Colors.white54, size: isMobile ? 18 : 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: onSearchChanged,
                        style: TextStyle(color: Colors.white, fontSize: isMobile ? 13 : 14),
                        decoration: InputDecoration(
                          hintText: isVeryNarrow
                              ? 'Search…'
                              : (isMobile ? 'Search music…' : 'Search songs, artists, albums, playlists...'),
                          hintStyle: TextStyle(color: Colors.white38, fontSize: isMobile ? 12 : 13),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (searchController.text.isNotEmpty)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 16),
                        onPressed: onClearSearch,
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: isMobile ? 6 : 12),
            const _AudioSourceSelectorButton(),
            if (!isMobile) ...[
              SizedBox(width: isMobile ? 4 : 8),
              _MusicHoverable(
                scaleFactor: 1.1,
                child: IconButton(
                  tooltip: 'Music Player Studio',
                  icon: const Icon(Icons.dashboard_customize_rounded, color: Colors.white70, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MusicPlayerStudioPage()),
                    );
                  },
                ),
              ),
              SizedBox(width: isMobile ? 2 : 6),
              _MusicHoverable(
                scaleFactor: 1.1,
                child: IconButton(
                  tooltip: 'Music Atmosphere Settings',
                  icon: const Icon(Icons.palette_rounded, color: Colors.white70, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MusicSettingsPage()),
                    );
                  },
                ),
              ),
            ],
            SizedBox(width: isMobile ? 2 : 6),
            _MusicHoverable(
              scaleFactor: 1.1,
              child: IconButton(
                tooltip: 'App Settings',
                icon: const Icon(Icons.settings_rounded, color: Colors.white70, size: 20),
                onPressed: onSettingsTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioSourceSelectorButton extends StatelessWidget {
  const _AudioSourceSelectorButton();

  @override
  Widget build(BuildContext context) {
    final player = MusicPlayerController.instance;

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final isFlac = player.audioSource == MusicAudioSource.flac;

        return _MusicHoverable(
          scaleFactor: 1.05,
          child: InkWell(
            onTap: () => _showAudioSourceDialog(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isFlac
                    ? const Color(0xFF00D2EF).withValues(alpha: 0.12)
                    : const Color(0xFFFF3366).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isFlac
                      ? const Color(0xFF00D2EF).withValues(alpha: 0.4)
                      : const Color(0xFFFF3366).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFlac ? Icons.diamond_rounded : Icons.play_circle_fill_rounded,
                    color: isFlac ? const Color(0xFF00D2EF) : const Color(0xFFFF3366),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isFlac ? 'FLAC' : 'YouTube',
                    style: TextStyle(
                      color: isFlac ? const Color(0xFF00D2EF) : const Color(0xFFFF6688),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: isFlac ? const Color(0xFF00D2EF) : const Color(0xFFFF6688),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void _showAudioSourceDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final player = MusicPlayerController.instance;

        return ListenableBuilder(
          listenable: player,
          builder: (context, _) {
            final isFlac = player.audioSource == MusicAudioSource.flac;

            return PerformanceLiquidLens(
              style: PerformanceGlassStyles.sheet,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F111D).withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.tune_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Audio Source & Quality',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Choose your preferred music extraction engine',
                              style: TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _sourceOptionCard(
                      title: 'FLAC Lossless (Qobuz Hi-Res)',
                      subtitle: 'Studio master quality up to 24-bit/192kHz with zero compression',
                      icon: Icons.diamond_rounded,
                      iconColor: const Color(0xFF00D2EF),
                      isSelected: isFlac,
                      badge: 'LOSSLESS',
                      badgeColor: const Color(0xFF00D2EF),
                      onTap: () {
                        player.setAudioSource(MusicAudioSource.flac);
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 12),
                    _sourceOptionCard(
                      title: 'YouTube Audio',
                      subtitle: 'High-speed audio extraction with intelligent track & duration matching',
                      icon: Icons.play_circle_fill_rounded,
                      iconColor: const Color(0xFFFF3366),
                      isSelected: !isFlac,
                      badge: 'FAST',
                      badgeColor: const Color(0xFFFF3366),
                      onTap: () {
                        player.setAudioSource(MusicAudioSource.youtube);
                        Navigator.pop(ctx);
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _sourceOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return _MusicHoverable(
      scaleFactor: 1.02,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? iconColor.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? iconColor.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.08),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: iconColor, size: 22)
              else
                const Icon(Icons.radio_button_unchecked_rounded, color: Colors.white30, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicMobileBottomNav extends StatelessWidget {
  final String activeTab;
  final Function(String) onTabSelected;

  const _MusicMobileBottomNav({
    required this.activeTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.dock,
      child: Container(
        height: 60 + bottomInset,
        padding: EdgeInsets.only(bottom: bottomInset),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0E17).withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem('Home', Icons.home_rounded),
            _navItem('Browse', Icons.explore_rounded),
            _navItem('Radio', Icons.radio_rounded),
            _navItem('Library', Icons.library_music_rounded),
          ],
        ),
      ),
    );
  }

  Widget _navItem(String label, IconData icon) {
    final isSelected = activeTab == label;
    return Expanded(
      child: FocusableCard(
        onTap: () => onTabSelected(label),
        builder: (context, _) => SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppThemeService.currentPalette.value.primaryColor : Colors.white54,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicHeroBillboard extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onPlayTap;
  final VoidCallback onSaveTap;
  final VoidCallback onAddToPlaylistTap;
  final bool isSaved;

  const _MusicHeroBillboard({
    required this.track,
    required this.onPlayTap,
    required this.onSaveTap,
    required this.onAddToPlaylistTap,
    required this.isSaved,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
      height: isMobile ? 190 : 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: track.coverUrl,
                cacheManager: AppImageCache.manager,
                fit: BoxFit.cover),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.94),
                      Colors.black.withValues(alpha: 0.65),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isMobile ? 18.0 : 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppThemeService.currentPalette.value.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'TOP CHART HIT',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    track.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 20 : 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artist,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isMobile ? 13 : 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: isMobile ? 14 : 20),
                  Row(
                    children: [
                      _MusicHoverable(
                        scaleFactor: 1.06,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: isMobile ? 16 : 20,
                              vertical: isMobile ? 10 : 12,
                            ),
                          ),
                          onPressed: onPlayTap,
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                          label: const Text(
                            'Play Now',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _MusicHoverable(
                        scaleFactor: 1.1,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                          ),
                          icon: Icon(
                            isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: isSaved ? const Color(0xFFFF4B72) : Colors.white,
                          ),
                          onPressed: onSaveTap,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _MusicHoverable(
                        scaleFactor: 1.1,
                        child: IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                          ),
                          icon: const Icon(Icons.playlist_add_rounded, color: Colors.white),
                          onPressed: onAddToPlaylistTap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicTrendingArtists extends StatelessWidget {
  final List<MusicArtist> artists;
  final Function(MusicArtist) onArtistTap;

  const _MusicTrendingArtists({
    required this.artists,
    required this.onArtistTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHorizontalScrollSection(
      title: '🌟 Trending Artists',
      height: 130,
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return FocusableCard(
          onTap: () => onArtistTap(artist),
          builder: (context, state) => AnimatedScale(
            scale: state.highlighted ? 1.06 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: artist.pictureUrl,
                      cacheManager: AppImageCache.manager,
                      memCacheWidth: 234,
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 85,
                  child: Text(
                    artist.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MusicAlbumsRow extends StatelessWidget {
  final String title;
  final List<MusicAlbum> albums;
  final Function(MusicAlbum) onAlbumTap;

  const _MusicAlbumsRow({
    required this.title,
    required this.albums,
    required this.onAlbumTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHorizontalScrollSection(
      title: title,
      height: 200,
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return _MusicAlbumCard(album: album, onTap: () => onAlbumTap(album));
      },
    );
  }
}

class _MusicPlaylistsRow extends StatelessWidget {
  final String title;
  final List<MusicPlaylist> playlists;
  final Function(MusicPlaylist) onPlaylistTap;

  const _MusicPlaylistsRow({
    required this.title,
    required this.playlists,
    required this.onPlaylistTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHorizontalScrollSection(
      title: title,
      height: 200,
      itemCount: playlists.length,
      itemBuilder: (context, index) {
        final pl = playlists[index];
        return _MusicPlaylistCard(playlist: pl, onTap: () => onPlaylistTap(pl));
      },
    );
  }
}

class _MusicCategorySlider extends StatelessWidget {
  final String title;
  final List<MusicTrack> tracks;
  final Function(MusicTrack) onAddToPlaylist;

  const _MusicCategorySlider({
    required this.title,
    required this.tracks,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHorizontalScrollSection(
      title: title,
      height: 215,
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _MusicTrackCard(
          track: track,
          onTap: () => MusicPlayerController.instance.playTrack(
            track,
            playlistQueue: tracks,
          ),
          onMoreTap: () => onAddToPlaylist(track),
        );
      },
    );
  }
}

class _MusicTrackCard extends StatelessWidget {
  final MusicTrack track;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _MusicTrackCard({
    required this.track,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onTap: onTap,
      builder: (context, state) => AnimatedScale(
        scale: state.highlighted ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 145,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: track.coverUrl,
                      cacheManager: AppImageCache.manager,
                      memCacheWidth: 435,
                      width: 145,
                      height: 145,
                      fit: BoxFit.cover),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppThemeService.currentPalette.value.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                track.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                track.artist,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicAlbumCard extends StatelessWidget {
  final MusicAlbum album;
  final VoidCallback onTap;

  const _MusicAlbumCard({
    required this.album,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onTap: onTap,
      builder: (context, state) => AnimatedScale(
        scale: state.highlighted ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 145,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: album.coverUrl,
                  cacheManager: AppImageCache.manager,
                  memCacheWidth: 435,
                  width: 145,
                  height: 145,
                  fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              Text(
                album.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                album.artistName,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicPlaylistCard extends StatelessWidget {
  final MusicPlaylist playlist;
  final VoidCallback onTap;

  const _MusicPlaylistCard({
    required this.playlist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FocusableCard(
      onTap: onTap,
      builder: (context, state) => AnimatedScale(
        scale: state.highlighted ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: SizedBox(
          width: 145,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: playlist.coverUrl,
                  cacheManager: AppImageCache.manager,
                  memCacheWidth: 435,
                  width: 145,
                  height: 145,
                  fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              Text(
                playlist.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${playlist.trackCount} tracks',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MusicTrackRow extends StatelessWidget {
  final MusicTrack track;
  final bool isPlaying;
  final bool isCurrent;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const _MusicTrackRow({
    required this.track,
    required this.isPlaying,
    required this.isCurrent,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return _MusicHoverable(
      scaleFactor: 1.01,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: isCurrent
            ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.15)
            : const Color(0xFF13151F),
        leading: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: track.coverUrl,
                cacheManager: AppImageCache.manager,
                memCacheWidth: 144,
                width: 48,
                height: 48,
                fit: BoxFit.cover),
            ),
            if (isCurrent)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: AppThemeService.currentPalette.value.primaryColor,
                  size: 28,
                ),
              ),
          ],
        ),
        title: Text(
          track.title,
          style: TextStyle(
            color: isCurrent ? AppThemeService.currentPalette.value.primaryColor : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.artist,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDownloadButton(context),
            const SizedBox(width: 4),
            Text(
              track.formattedDuration,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
              onPressed: onMoreTap,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context) {
    final isDownloaded = MusicDownloadService.instance.isDownloaded(track.id);
    final task = MusicDownloadService.instance.getTask(track.id);
    final isDownloading = task != null &&
        (task.status == MusicDownloadStatus.extracting || task.status == MusicDownloadStatus.downloading);
    final isQueued = task != null && task.status == MusicDownloadStatus.queued;

    if (isDownloaded) {
      return Tooltip(
        message: 'Downloaded (Offline)',
        child: Container(
          padding: const EdgeInsets.all(6),
          child: const Icon(
            Icons.download_done_rounded,
            color: Color(0xFF00E5FF),
            size: 18,
          ),
        ),
      );
    }

    if (isDownloading) {
      return Tooltip(
        message: 'Downloading ${(task.progress * 100).toInt()}%',
        child: Container(
          width: 28,
          height: 28,
          padding: const EdgeInsets.all(5),
          child: CircularProgressIndicator(
            value: task.progress > 0.05 ? task.progress : null,
            strokeWidth: 2.2,
            color: const Color(0xFF00E5FF),
          ),
        ),
      );
    }

    if (isQueued) {
      return Tooltip(
        message: 'Queued for download',
        child: Container(
          padding: const EdgeInsets.all(6),
          child: const Icon(
            Icons.hourglass_top_rounded,
            color: Colors.amberAccent,
            size: 18,
          ),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.download_rounded, color: Colors.white38, size: 18),
      tooltip: 'Download Track',
      onPressed: () {
        MusicDownloadService.instance.queueTrack(track);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${track.title}" to download queue'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

class _MusicCardSizing {
  final double cardWidth;
  final double totalHeight;

  const _MusicCardSizing(this.cardWidth, this.totalHeight);

  factory _MusicCardSizing.fromWidth(double width) {
    if (width >= 1200) return const _MusicCardSizing(170, 240);
    if (width >= 800) return const _MusicCardSizing(150, 215);
    if (width >= 450) return const _MusicCardSizing(140, 200);
    return const _MusicCardSizing(125, 185);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Drawers & Modals
// ─────────────────────────────────────────────────────────────────────────────

class _MusicBottomPlayerBar extends StatelessWidget {
  final MusicPlayerController playerController;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onExpandTap;
  final VoidCallback onQueueTap;
  final VoidCallback onLyricsTap;
  final VoidCallback onAddToPlaylist;

  const _MusicBottomPlayerBar({
    required this.playerController,
    required this.isSaved,
    required this.onToggleSave,
    required this.onExpandTap,
    required this.onQueueTap,
    required this.onLyricsTap,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final track = playerController.currentTrack;
    if (track == null) return const SizedBox.shrink();
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final palette = AppThemeService.currentPalette.value;
    final preset = MusicSettings.selectedMiniPreset.value;

    return FocusableCard(
      onTap: onExpandTap,
      builder: (context, _) => PerformanceLiquidLens(
        style: PerformanceGlassStyles.dock,
        child: _buildPresetContainer(preset, palette, isMobile, track),
      ),
    );
  }

  Widget _buildPresetContainer(MusicMiniPlayerPreset preset, AppThemePalette palette, bool isMobile, MusicTrack track) {
    if (preset == MusicMiniPlayerPreset.compactPill) {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F121C).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: palette.primaryColor.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildArtwork(track, size: 38, radius: 19),
            const SizedBox(width: 10),
            Expanded(child: _buildTrackInfo(track, isMobile, palette)),
            _buildControls(isMobile, palette, mini: true),
          ],
        ),
      );
    }

    if (preset == MusicMiniPlayerPreset.gradientWave) {
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.primaryColor.withValues(alpha: 0.28),
              const Color(0xFF10131E).withValues(alpha: 0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.primaryColor.withValues(alpha: 0.5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.3),
              blurRadius: 26,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildArtwork(track, size: 44, radius: 12),
            const SizedBox(width: 12),
            Expanded(child: _buildTrackInfo(track, isMobile, palette)),
            _buildControls(isMobile, palette),
          ],
        ),
      );
    }

    if (preset == MusicMiniPlayerPreset.minimalistLine) {
      return Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D14).withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            _buildArtwork(track, size: 34, radius: 6),
            const SizedBox(width: 10),
            Expanded(child: _buildTrackInfo(track, isMobile, palette, compact: true)),
            _buildControls(isMobile, palette, mini: true),
          ],
        ),
      );
    }

    if (preset == MusicMiniPlayerPreset.customStudio) {
      final order = MusicSettings.componentOrderMini.value;
      return Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF131522).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.primaryColor.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: order.map((key) {
            switch (key) {
              case 'artwork':
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildArtwork(track, size: 44, radius: 10),
                    const SizedBox(width: 12),
                  ],
                );
              case 'trackInfo':
                return Expanded(child: _buildTrackInfo(track, isMobile, palette));
              case 'mainControls':
                return _buildControls(isMobile, palette);
              case 'extraActions':
                return !isMobile
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isSaved ? const Color(0xFFFF4B72) : Colors.white60,
                              size: 20,
                            ),
                            onPressed: onToggleSave,
                          ),
                        ],
                      )
                    : const SizedBox.shrink();
              default:
                return const SizedBox.shrink();
            }
          }).toList(),
        ),
      );
    }

    // Default: Floating Glass Island
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131522).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.primaryColor.withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.2),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          _buildArtwork(track, size: 44, radius: 10),
          const SizedBox(width: 12),
          Expanded(child: _buildTrackInfo(track, isMobile, palette)),
          _buildControls(isMobile, palette),
        ],
      ),
    );
  }

  Widget _buildArtwork(MusicTrack track, {required double size, required double radius}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: track.coverUrl,
        cacheManager: AppImageCache.manager,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: size,
          height: size,
          color: const Color(0xFF1A1D2E),
          child: const Icon(Icons.music_note_rounded, color: Colors.white54, size: 20),
        )),
    );
  }

  Widget _buildTrackInfo(MusicTrack track, bool isMobile, AppThemePalette palette, {bool compact = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: compact ? 12 : 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: Text(
                track.artist,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (MusicSettings.showLosslessBadge.value) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: playerController.isCurrentTrackLossless
                      ? const Color(0xFF00D2EF).withValues(alpha: 0.15)
                      : const Color(0xFFFF3366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: playerController.isCurrentTrackLossless
                        ? const Color(0xFF00D2EF).withValues(alpha: 0.35)
                        : const Color(0xFFFF3366).withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  playerController.currentQualityLabel,
                  style: TextStyle(
                    color: playerController.isCurrentTrackLossless
                        ? const Color(0xFF00D2EF)
                        : const Color(0xFFFF6688),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildControls(bool isMobile, AppThemePalette palette, {bool mini = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMobile) ...[
          IconButton(
            icon: Icon(
              isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isSaved ? const Color(0xFFFF4B72) : Colors.white60,
              size: 20,
            ),
            onPressed: onToggleSave,
          ),
          IconButton(
            icon: const Icon(Icons.format_quote_rounded, color: Colors.white60, size: 20),
            onPressed: onLyricsTap,
          ),
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, color: Colors.white),
            onPressed: playerController.playPrevious,
          ),
        ],
        _buildPlayPauseButton(palette, mini: mini),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
          onPressed: playerController.playNext,
        ),
        if (!isMobile)
          IconButton(
            icon: const Icon(Icons.queue_music_rounded, color: Colors.white60, size: 20),
            onPressed: onQueueTap,
          ),
      ],
    );
  }

  Widget _buildPlayPauseButton(AppThemePalette palette, {bool mini = false}) {
    final hoverEffect = MusicSettings.customHoverEffect.value;
    final playBtnStyle = MusicSettings.customPlayButtonStyle.value;

    return MusicInteractivePhysicsButton(
      effect: hoverEffect,
      glowColor: palette.primaryColor,
      borderRadius: BorderRadius.circular(mini ? 16 : 22),
      onTap: playerController.togglePlayPause,
      child: playerController.isLoading
          ? SizedBox(
              width: mini ? 24 : 32,
              height: mini ? 24 : 32,
              child: CircularProgressIndicator(
                color: palette.primaryColor,
                strokeWidth: 2.5,
              ),
            )
          : _buildPlayButtonIcon(playBtnStyle, palette, mini),
    );
  }

  Widget _buildPlayButtonIcon(MusicPlayButtonStyle style, AppThemePalette palette, bool mini) {
    final isPlaying = playerController.isPlaying;
    final icon = isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final size = mini ? 32.0 : 40.0;
    final iconSize = mini ? 20.0 : 26.0;

    if (style == MusicPlayButtonStyle.liquidGlassNeo) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: palette.primaryColor.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
    }

    if (style == MusicPlayButtonStyle.neonSquare) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(mini ? 8 : 12),
          gradient: LinearGradient(colors: [palette.primaryColor, palette.accentColor]),
          boxShadow: [
            BoxShadow(color: palette.primaryColor.withValues(alpha: 0.5), blurRadius: 12),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
    }

    // Default: Circle Glow
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [palette.primaryColor, palette.accentColor]),
        boxShadow: [
          BoxShadow(color: palette.primaryColor.withValues(alpha: 0.55), blurRadius: 14),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
    );
  }
}

class _MusicLyricsDrawer extends StatelessWidget {
  final MusicTrack track;
  final MusicPlayerController playerController;
  final VoidCallback onClose;

  const _MusicLyricsDrawer({
    required this.track,
    required this.playerController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final lyrics = playerController.currentLyrics;
    final activeIndex = playerController.activeLyricIndex;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: isMobile ? MediaQuery.sizeOf(context).width : 360,
        decoration: BoxDecoration(
          color: const Color(0xFF0F121C).withValues(alpha: 0.96),
          borderRadius: isMobile
              ? const BorderRadius.vertical(top: Radius.circular(24))
              : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: AppThemeService.currentPalette.value.primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Text(
                  'Synced Lyrics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (playerController.isLoadingLyrics)
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppThemeService.currentPalette.value.primaryColor),
                ),
              )
            else if (!lyrics.isSynced && lyrics.plainLyrics.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No lyrics found for this track.',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              )
            else if (lyrics.isSynced)
              Expanded(
                child: ListView.builder(
                  itemCount: lyrics.syncedLines.length,
                  itemBuilder: (context, index) {
                    final line = lyrics.syncedLines[index];
                    final isActive = index == activeIndex;
                    return FocusableCard(
                      onTap: () => playerController.seekTo(line.timestamp),
                      builder: (context, _) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text(
                          line.text,
                          style: TextStyle(
                            color: isActive
                                ? AppThemeService.currentPalette.value.primaryColor
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: isActive ? 18 : 15,
                            fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    lyrics.plainLyrics,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MusicQueueDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const _MusicQueueDrawer({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final controller = MusicPlayerController.instance;
    final queue = controller.playlist;
    final currentIndex = controller.currentIndex;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: isMobile ? MediaQuery.sizeOf(context).width : 360,
        decoration: BoxDecoration(
          color: const Color(0xFF0F121C).withValues(alpha: 0.96),
          borderRadius: isMobile
              ? const BorderRadius.vertical(top: Radius.circular(24))
              : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  bottomLeft: Radius.circular(24),
                ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.queue_music_rounded,
                  color: AppThemeService.currentPalette.value.primaryColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Queue (${queue.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                if (queue.isNotEmpty)
                  TextButton(
                    onPressed: controller.clearQueue,
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (queue.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'Queue is empty',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: queue.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final track = queue[index];
                    final isCurrent = index == currentIndex;
                    return ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isCurrent
                          ? AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.2)
                          : const Color(0xFF13151F),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: track.coverUrl,
                          cacheManager: AppImageCache.manager,
                          memCacheWidth: 108,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover),
                      ),
                      title: Text(
                        track.title,
                        style: TextStyle(
                          color: isCurrent ? AppThemeService.currentPalette.value.primaryColor : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        track.artist,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 16),
                        onPressed: () => controller.removeFromQueue(index),
                      ),
                      onTap: () => controller.playTrack(track, playlistQueue: queue),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MusicArtistDetailModal extends StatelessWidget {
  final MusicArtistDetails details;
  final VoidCallback onClose;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;
  final Function(String) onOpenAlbum;

  const _MusicArtistDetailModal({
    required this.details,
    required this.onClose,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
    required this.onOpenAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final artist = details.artist;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: isMobile ? size.width - 24 : 720,
            height: isMobile ? size.height * 0.85 : 640,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: artist.pictureUrl,
                        cacheManager: AppImageCache.manager,
                        fit: BoxFit.cover),
                    ),
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Color(0xFF0F121C),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                        onPressed: onClose,
                      ),
                    ),
                    Positioned(
                      left: 24,
                      bottom: 16,
                      child: Row(
                        children: [
                          Text(
                            artist.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (details.topTracks.isNotEmpty)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () => onPlayTrack(details.topTracks.first, details.topTracks),
                              icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                              label: const Text('Play All', style: TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    children: [
                      if (details.topTracks.isNotEmpty) ...[
                        const Text(
                          'Top Songs',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: details.topTracks.length.clamp(0, 10),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final track = details.topTracks[index];
                            return _MusicTrackRow(
                              track: track,
                              isPlaying: false,
                              isCurrent: false,
                              onTap: () => onPlayTrack(track, details.topTracks),
                              onMoreTap: () => onAddToPlaylist(track),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (details.albums.isNotEmpty) ...[
                        const Text(
                          'Albums & Discography',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 180,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: details.albums.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final album = details.albums[index];
                              return _MusicAlbumCard(album: album, onTap: () => onOpenAlbum(album.id));
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicAlbumDetailModal extends StatelessWidget {
  final MusicAlbumDetails details;
  final VoidCallback onClose;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;

  const _MusicAlbumDetailModal({
    required this.details,
    required this.onClose,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final album = details.album;
    final tracks = details.tracks;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: isMobile ? size.width - 24 : 720,
            height: isMobile ? size.height * 0.85 : 640,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: album.coverUrl,
                        cacheManager: AppImageCache.manager,
                        width: isMobile ? 80 : 120,
                        height: isMobile ? 80 : 120,
                        fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            album.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            album.artistName,
                            style: TextStyle(
                              color: AppThemeService.currentPalette.value.primaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${tracks.length} tracks • ${album.releaseDate}',
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          if (tracks.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => onPlayTrack(tracks.first, tracks),
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  label: const Text('Play Album', style: TextStyle(color: Colors.white)),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    MusicDownloadService.instance.queueTracks(tracks, collectionName: album.title);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added ${tracks.length} tracks from "${album.title}" to download queue'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Download Album'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return _MusicTrackRow(
                        track: track,
                        isPlaying: false,
                        isCurrent: false,
                        onTap: () => onPlayTrack(track, tracks),
                        onMoreTap: () => onAddToPlaylist(track),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicCuratedPlaylistDetailModal extends StatelessWidget {
  final MusicPlaylistDetails details;
  final VoidCallback onClose;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;

  const _MusicCuratedPlaylistDetailModal({
    required this.details,
    required this.onClose,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
  });

  @override
  Widget build(BuildContext context) {
    final playlist = details.playlist;
    final tracks = details.tracks;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: isMobile ? size.width - 24 : 720,
            height: isMobile ? size.height * 0.85 : 640,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: playlist.coverUrl,
                        cacheManager: AppImageCache.manager,
                        width: isMobile ? 80 : 120,
                        height: isMobile ? 80 : 120,
                        fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.w900,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Curated by ${playlist.creatorName} • ${tracks.length} tracks',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          if (tracks.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => onPlayTrack(tracks.first, tracks),
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  label: const Text('Play Playlist', style: TextStyle(color: Colors.white)),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    MusicDownloadService.instance.queueTracks(tracks, collectionName: playlist.title);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added ${tracks.length} tracks from "${playlist.title}" to download queue'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Download Playlist'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: tracks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      return _MusicTrackRow(
                        track: track,
                        isPlaying: false,
                        isCurrent: false,
                        onTap: () => onPlayTrack(track, tracks),
                        onMoreTap: () => onAddToPlaylist(track),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicUserPlaylistDetailModal extends StatelessWidget {
  final UserPlaylist playlist;
  final VoidCallback onClose;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(String) onRemoveTrack;

  const _MusicUserPlaylistDetailModal({
    required this.playlist,
    required this.onClose,
    required this.onPlayTrack,
    required this.onRemoveTrack,
  });

  @override
  Widget build(BuildContext context) {
    final tracks = playlist.tracks;
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: isMobile ? size.width - 24 : 720,
            height: isMobile ? size.height * 0.85 : 640,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: isMobile ? 80 : 120,
                      height: isMobile ? 80 : 120,
                      decoration: BoxDecoration(
                        color: AppThemeService.currentPalette.value.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: AppThemeService.currentPalette.value.primaryColor,
                        size: isMobile ? 36 : 48,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            playlist.title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Custom Playlist • ${tracks.length} tracks',
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          if (tracks.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () => onPlayTrack(tracks.first, tracks),
                                  icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                                  label: const Text('Play Playlist', style: TextStyle(color: Colors.white)),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  onPressed: () {
                                    MusicDownloadService.instance.queueTracks(tracks, collectionName: playlist.title);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added ${tracks.length} tracks from "${playlist.title}" to download queue'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download_rounded, size: 18),
                                  label: const Text('Download All'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 8),
                Expanded(
                  child: tracks.isEmpty
                      ? const Center(
                          child: Text(
                            'No tracks in this playlist yet',
                            style: TextStyle(color: Colors.white38),
                          ),
                        )
                      : ListView.separated(
                          itemCount: tracks.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final track = tracks[index];
                            return ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              tileColor: const Color(0xFF13151F),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: track.coverUrl,
                                  cacheManager: AppImageCache.manager,
                                  memCacheWidth: 132,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover),
                              ),
                              title: Text(
                                track.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                track.artist,
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                                onPressed: () => onRemoveTrack(track.id),
                              ),
                              onTap: () => onPlayTrack(track, tracks),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicExpandedPlayer extends StatefulWidget {
  final MusicPlayerController playerController;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final VoidCallback onCollapse;
  final VoidCallback onQueueTap;
  final VoidCallback onAddToPlaylist;

  const _MusicExpandedPlayer({
    required this.playerController,
    required this.isSaved,
    required this.onToggleSave,
    required this.onCollapse,
    required this.onQueueTap,
    required this.onAddToPlaylist,
  });

  @override
  State<_MusicExpandedPlayer> createState() => _MusicExpandedPlayerState();
}

class _MusicExpandedPlayerState extends State<_MusicExpandedPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _discAnimController;

  @override
  void initState() {
    super.initState();
    _discAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.playerController.isPlaying) {
      _discAnimController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MusicExpandedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playerController.isPlaying && !_discAnimController.isAnimating) {
      _discAnimController.repeat();
    } else if (!widget.playerController.isPlaying && _discAnimController.isAnimating) {
      _discAnimController.stop();
    }
  }

  @override
  void dispose() {
    _discAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.playerController.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final palette = AppThemeService.currentPalette.value;
    final preset = MusicSettings.selectedFullscreenPreset.value;
    final seekStyle = MusicSettings.customSeekbarStyle.value;
    final artStyle = MusicSettings.customArtworkStyle.value;
    final order = MusicSettings.componentOrderFullscreen.value;

    final screenSize = MediaQuery.sizeOf(context);
    final isDesktop = screenSize.width >= 800;
    final artSize = isDesktop
        ? 230.0
        : math.min(screenSize.width * 0.75, screenSize.height * 0.38);

    final playerBody = Column(
      children: [
        // Top Navigation & Actions Bar
        Row(
          children: [
            _MusicHoverable(
              scaleFactor: 1.1,
              child: IconButton(
                icon: Icon(
                  isDesktop ? Icons.close_rounded : Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                  size: isDesktop ? 24 : 32,
                ),
                onPressed: widget.onCollapse,
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: () => _AudioSourceSelectorButton._showAudioSourceDialog(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.playerController.isCurrentTrackLossless
                      ? const Color(0xFF00D2EF).withValues(alpha: 0.15)
                      : const Color(0xFFFF3366).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.playerController.isCurrentTrackLossless
                        ? const Color(0xFF00D2EF).withValues(alpha: 0.4)
                        : const Color(0xFFFF3366).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.playerController.isCurrentTrackLossless
                          ? Icons.diamond_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 13,
                      color: widget.playerController.isCurrentTrackLossless
                          ? const Color(0xFF00D2EF)
                          : const Color(0xFFFF6688),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.playerController.currentQualityLabel.toUpperCase(),
                      style: TextStyle(
                        color: widget.playerController.isCurrentTrackLossless
                            ? const Color(0xFF00D2EF)
                            : const Color(0xFFFF6688),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: widget.playerController.isCurrentTrackLossless
                          ? const Color(0xFF00D2EF)
                          : const Color(0xFFFF6688),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            _MusicHoverable(
              scaleFactor: 1.1,
              child: IconButton(
                icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
                onPressed: widget.onAddToPlaylist,
              ),
            ),
          ],
        ),
        if (!isDesktop) const Spacer() else const SizedBox(height: 12),

        // Preset-based or Custom Arranged Body
        if (preset == MusicFullscreenPreset.customStudio)
          ...order.map((key) => _buildCustomComponent(key, track, palette, seekStyle, artStyle, artSize))
        else
          ..._buildPresetBody(preset, track, palette, seekStyle, artSize),

        if (!isDesktop) const Spacer() else const SizedBox(height: 12),
      ],
    );

    if (isDesktop) {
      return Stack(
        alignment: Alignment.center,
        children: [
          // Dismissible Scrim with blur
          Positioned.fill(
            child: GestureDetector(
              onTap: widget.onCollapse,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
          // Floating Modal Card
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 540,
                maxHeight: math.min(740, screenSize.height * 0.88),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0B0D14),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.75),
                      blurRadius: 40,
                      spreadRadius: 8,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    children: [
                      // Ambient blurred cover backdrop
                      Positioned.fill(
                        child: Opacity(
                          opacity: 0.25,
                          child: CachedNetworkImage(
                            imageUrl: track.coverUrl,
                            cacheManager: AppImageCache.manager,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const SizedBox.shrink()),
                        ),
                      ),
                      Positioned.fill(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                          child: Container(
                            color: const Color(0xFF0B0D14).withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                        child: playerBody,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      color: const Color(0xFF07090F),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient blurred cover backdrop
          Positioned.fill(
            child: Opacity(
              opacity: 0.28,
              child: CachedNetworkImage(
                imageUrl: track.coverUrl,
                cacheManager: AppImageCache.manager,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink()),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(
                color: const Color(0xFF07090F).withValues(alpha: 0.85),
              ),
            ),
          ),

          // Main Expanded Player Column
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
              child: playerBody,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPresetBody(
    MusicFullscreenPreset preset,
    MusicTrack track,
    AppThemePalette palette,
    MusicSeekbarStyle seekStyle,
    double artSize,
  ) {
    return [
      // Artwork Section
      if (preset == MusicFullscreenPreset.vinylStudio)
        _buildVinylDiscArtwork(track, artSize, palette)
      else if (preset == MusicFullscreenPreset.cyberWaveform)
        _buildCyberWaveArtwork(track, artSize, palette)
      else if (preset == MusicFullscreenPreset.liquidGlassNeo)
        _buildLiquidGlassArtwork(track, artSize, palette)
      else
        _buildCinematicArtwork(track, artSize),

      const SizedBox(height: 24),

      // Track & Artist Title Row with Like Button
      _buildTitleRow(track),

      const SizedBox(height: 16),

      // Scrubber Canvas
      MusicWaveformSeekbar(
        position: widget.playerController.position,
        duration: widget.playerController.duration,
        isPlaying: widget.playerController.isPlaying,
        style: preset == MusicFullscreenPreset.cyberWaveform
            ? MusicSeekbarStyle.waveformEqualizer
            : (preset == MusicFullscreenPreset.liquidGlassNeo
                ? MusicSeekbarStyle.liquidGlassSlider
                : seekStyle),
        onSeek: (pos) => widget.playerController.seekTo(pos),
      ),

      const SizedBox(height: 16),

      // Main Controls
      _buildPlaybackControlsRow(palette),
    ];
  }

  Widget _buildCustomComponent(
    String key,
    MusicTrack track,
    AppThemePalette palette,
    MusicSeekbarStyle seekStyle,
    MusicArtworkStyle artStyle,
    double artSize,
  ) {
    switch (key) {
      case 'artwork':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildCustomArtworkByStyle(track, artSize, palette, artStyle),
        );
      case 'title':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildTitleRow(track),
        );
      case 'qualityBadge':
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00D2EF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00D2EF).withValues(alpha: 0.4)),
            ),
            child: Text(
              '${widget.playerController.currentQualityLabel.toUpperCase()} • HI-RES LOSSLESS AUDIO',
              style: const TextStyle(color: Color(0xFF00D2EF), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6),
            ),
          ),
        );
      case 'seekbar':
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MusicWaveformSeekbar(
            position: widget.playerController.position,
            duration: widget.playerController.duration,
            isPlaying: widget.playerController.isPlaying,
            style: seekStyle,
            onSeek: (pos) => widget.playerController.seekTo(pos),
          ),
        );
      case 'mainControls':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPlaybackControlsRow(palette),
        );
      case 'secondaryControls':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.format_quote_rounded, color: Colors.white70, size: 22),
                onPressed: widget.onCollapse,
              ),
              IconButton(
                icon: const Icon(Icons.queue_music_rounded, color: Colors.white70, size: 22),
                onPressed: widget.onQueueTap,
              ),
            ],
          ),
        );
      case 'extraActions':
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: widget.onQueueTap,
                icon: Icon(Icons.queue_music_rounded, color: palette.primaryColor, size: 16),
                label: const Text('Playing Queue', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.primaryColor.withValues(alpha: 0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTitleRow(MusicTrack track) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                track.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                track.artist,
                style: const TextStyle(color: Colors.white60, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        MusicInteractivePhysicsButton(
          effect: MusicSettings.customHoverEffect.value,
          glowColor: const Color(0xFFFF4B72),
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onToggleSave,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(
              widget.isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: widget.isSaved ? const Color(0xFFFF4B72) : Colors.white70,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControlsRow(AppThemePalette palette) {
    final hoverEffect = MusicSettings.customHoverEffect.value;
    final playBtnStyle = MusicSettings.customPlayButtonStyle.value;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onTap: widget.playerController.toggleShuffle,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              Icons.shuffle_rounded,
              color: widget.playerController.isShuffle ? palette.primaryColor : Colors.white38,
              size: 24,
            ),
          ),
        ),
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onTap: widget.playerController.playPrevious,
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.skip_previous_rounded, color: Colors.white, size: 36),
          ),
        ),
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(32),
          onTap: widget.playerController.togglePlayPause,
          child: widget.playerController.isLoading
              ? SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(color: palette.primaryColor, strokeWidth: 3),
                )
              : _buildExpandedPlayButtonIcon(playBtnStyle, palette),
        ),
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onTap: widget.playerController.playNext,
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.skip_next_rounded, color: Colors.white, size: 36),
          ),
        ),
        MusicInteractivePhysicsButton(
          effect: hoverEffect,
          glowColor: palette.primaryColor,
          borderRadius: BorderRadius.circular(14),
          onTap: widget.playerController.toggleRepeat,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              widget.playerController.repeatMode == MusicRepeatMode.one
                  ? Icons.repeat_one_rounded
                  : Icons.repeat_rounded,
              color: widget.playerController.repeatMode != MusicRepeatMode.off ? palette.primaryColor : Colors.white38,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedPlayButtonIcon(MusicPlayButtonStyle style, AppThemePalette palette) {
    final isPlaying = widget.playerController.isPlaying;
    final icon = isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;

    if (style == MusicPlayButtonStyle.liquidGlassNeo) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: palette.primaryColor.withValues(alpha: 0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.5),
              blurRadius: 20,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 38),
      );
    }

    if (style == MusicPlayButtonStyle.neonSquare) {
      return Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [palette.primaryColor, palette.accentColor]),
          boxShadow: [
            BoxShadow(color: palette.primaryColor.withValues(alpha: 0.6), blurRadius: 20),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 38),
      );
    }

    // Default: Circle Glow
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [palette.primaryColor, palette.accentColor]),
        boxShadow: [
          BoxShadow(color: palette.primaryColor.withValues(alpha: 0.6), blurRadius: 22, spreadRadius: 2),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 40),
    );
  }

  Widget _buildVinylDiscArtwork(MusicTrack track, double size, AppThemePalette palette) {
    return AnimatedBuilder(
      animation: _discAnimController,
      builder: (context, child) => Transform.rotate(
        angle: widget.playerController.isPlaying ? _discAnimController.value * 2 * math.pi : 0,
        child: child,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF10131E),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 4),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.4),
              blurRadius: 36,
            ),
          ],
        ),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: CachedNetworkImage(
              imageUrl: track.coverUrl,
              cacheManager: AppImageCache.manager,
              width: size * 0.44,
              height: size * 0.44,
              fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildCyberWaveArtwork(MusicTrack track, double size, AppThemePalette palette) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: palette.primaryColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: palette.primaryColor.withValues(alpha: 0.45),
            blurRadius: 30,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: CachedNetworkImage(
          imageUrl: track.coverUrl,
          cacheManager: AppImageCache.manager,
          fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildLiquidGlassArtwork(MusicTrack track, double size, AppThemePalette palette) {
    return PerformanceLiquidLens(
      style: PerformanceGlassStyles.sheet,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.35),
              blurRadius: 28,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: CachedNetworkImage(
            imageUrl: track.coverUrl,
            cacheManager: AppImageCache.manager,
            fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildCinematicArtwork(MusicTrack track, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: CachedNetworkImage(
        imageUrl: track.coverUrl,
        cacheManager: AppImageCache.manager,
        width: size,
        height: size,
        fit: BoxFit.cover),
    );
  }

  Widget _buildCustomArtworkByStyle(MusicTrack track, double size, AppThemePalette palette, MusicArtworkStyle style) {
    if (style == MusicArtworkStyle.vinylSpinningDisc) {
      return _buildVinylDiscArtwork(track, size, palette);
    }
    if (style == MusicArtworkStyle.floatingCard3D) {
      return _buildLiquidGlassArtwork(track, size, palette);
    }
    if (style == MusicArtworkStyle.glowSphere) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.primaryColor.withValues(alpha: 0.5),
              blurRadius: 36,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size / 2),
          child: CachedNetworkImage(
            imageUrl: track.coverUrl,
            cacheManager: AppImageCache.manager,
            fit: BoxFit.cover),
        ),
      );
    }
    return _buildCinematicArtwork(track, size);
  }
}

class _MusicShortcutsModal extends StatelessWidget {
  final VoidCallback onClose;

  const _MusicShortcutsModal({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      {'key': 'Space / K', 'desc': 'Toggle Play / Pause'},
      {'key': 'J', 'desc': 'Seek -5 seconds backward'},
      {'key': 'L', 'desc': 'Seek +5 seconds forward'},
      {'key': 'M', 'desc': 'Toggle Mute / Unmute'},
      {'key': 'Q', 'desc': 'Toggle Queue Drawer'},
      {'key': 'F', 'desc': 'Toggle Fullscreen Now Playing'},
      {'key': '? / Shift + /', 'desc': 'Show Shortcuts'},
    ];

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.keyboard_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'Keyboard Shortcuts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final s in shortcuts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1E2B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            s['key']!,
                            style: TextStyle(
                              color: AppThemeService.currentPalette.value.primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          s['desc']!,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MusicDownloadedTracksModal extends StatefulWidget {
  final VoidCallback onClose;
  final Function(MusicTrack, List<MusicTrack>) onPlayTrack;
  final Function(MusicTrack) onAddToPlaylist;

  const _MusicDownloadedTracksModal({
    required this.onClose,
    required this.onPlayTrack,
    required this.onAddToPlaylist,
  });

  @override
  State<_MusicDownloadedTracksModal> createState() => _MusicDownloadedTracksModalState();
}

class _MusicDownloadedTracksModalState extends State<_MusicDownloadedTracksModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final downloadService = MusicDownloadService.instance;
    final allDownloaded = downloadService.downloadedTracks;
    final queue = downloadService.queue;
    final totalBytes = downloadService.totalDownloadedSizeBytes;
    final sizeMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    final filtered = _searchQuery.isEmpty
        ? allDownloaded
        : allDownloaded.where((t) =>
            t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.artist.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.album.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 700;

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: PerformanceLiquidLens(
          style: PerformanceGlassStyles.sheet,
          child: Container(
            width: isMobile ? size.width - 24 : 760,
            height: isMobile ? size.height * 0.88 : 660,
            decoration: BoxDecoration(
              color: const Color(0xFF0F121C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: isMobile ? 48 : 56,
                      height: isMobile ? 48 : 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0083B0), Color(0xFF00B4DB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.offline_pin_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Downloaded Songs',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 19 : 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${allDownloaded.length} offline tracks • $sizeMb MB storage',
                            style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Active Download Queue Card
                if (queue.isNotEmpty) ...[
                  _buildQueueBanner(queue, downloadService),
                  const SizedBox(height: 12),
                ],

                // Action Bar: Play All, Shuffle, Search
                Row(
                  children: [
                    if (filtered.isNotEmpty) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4DB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () {
                          final tracks = filtered.map((d) => d.toMusicTrack()).toList();
                          widget.onPlayTrack(tracks.first, tracks);
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 20),
                        label: const Text('Play All', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onPressed: () {
                          final tracks = filtered.map((d) => d.toMusicTrack()).toList()..shuffle();
                          widget.onPlayTrack(tracks.first, tracks);
                        },
                        icon: const Icon(Icons.shuffle_rounded, size: 18),
                        label: const Text('Shuffle'),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(
                      width: isMobile ? 140 : 200,
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Search offline...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00B4DB), size: 16),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(color: Colors.white10),
                const SizedBox(height: 6),

                // Downloaded Tracks List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.cloud_download_rounded,
                                color: Colors.white24,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No downloaded tracks match "$_searchQuery"'
                                    : 'No offline downloads yet.\nTap the download icon on any song, album, or playlist to listen offline.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54, fontSize: 13.5, height: 1.4),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final item = filtered[index];
                            final track = item.toMusicTrack();
                            final itemSizeMb = (item.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
                            final isFlac = item.format.toLowerCase() == 'flac';

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              tileColor: const Color(0xFF13151F),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: item.localCoverPath.isNotEmpty && File(item.localCoverPath).existsSync()
                                    ? Image.file(
                                        File(item.localCoverPath),
                                        width: 46,
                                        height: 46,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _buildFallbackCover(track),
                                      )
                                    : _buildFallbackCover(track),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.artist} • ${item.album}',
                                      style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isFlac
                                          ? const Color(0xFF7C5CFF).withValues(alpha: 0.25)
                                          : const Color(0xFF00B0FF).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isFlac ? 'FLAC' : item.format.toUpperCase(),
                                      style: TextStyle(
                                        color: isFlac ? const Color(0xFFB39DDB) : const Color(0xFF00E5FF),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$itemSizeMb MB',
                                    style: const TextStyle(color: Colors.white38, fontSize: 10.5),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 20),
                                    tooltip: 'Delete from downloads',
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (c) => AlertDialog(
                                          backgroundColor: const Color(0xFF161924),
                                          title: const Text('Delete Downloaded Song', style: TextStyle(color: Colors.white)),
                                          content: Text('Delete "${item.title}" from offline storage?', style: const TextStyle(color: Colors.white70)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(c, false),
                                              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                              onPressed: () => Navigator.pop(c, true),
                                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await downloadService.deleteDownloadedTrack(item.id);
                                        setState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                              onTap: () {
                                final allTracks = filtered.map((d) => d.toMusicTrack()).toList();
                                widget.onPlayTrack(track, allTracks);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackCover(MusicTrack track) {
    if (track.coverUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: track.coverUrl,
        cacheManager: AppImageCache.manager,
        memCacheWidth: 138,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => Container(
          width: 46,
          height: 46,
          color: const Color(0xFF1B1E2B),
          child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 24),
        ));
    }
    return Container(
      width: 46,
      height: 46,
      color: const Color(0xFF1B1E2B),
      child: const Icon(Icons.music_note_rounded, color: Colors.white38, size: 24),
    );
  }

  Widget _buildQueueBanner(List<MusicDownloadTask> queue, MusicDownloadService service) {
    final activeTask = queue.firstWhere(
      (t) => t.status == MusicDownloadStatus.downloading || t.status == MusicDownloadStatus.extracting,
      orElse: () => queue.first,
    );
    final isExtracting = activeTask.status == MusicDownloadStatus.extracting;
    final progress = activeTask.progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0083B0).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF00B4DB).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: isExtracting ? null : progress,
                  color: const Color(0xFF00E5FF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isExtracting
                      ? 'Extracting stream for "${activeTask.track.title}"...'
                      : 'Downloading "${activeTask.track.title}" (${(progress * 100).toInt()}%)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${queue.length} in queue',
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => service.cancelTask(activeTask.track.id),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, color: Colors.white60, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: isExtracting ? null : progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
