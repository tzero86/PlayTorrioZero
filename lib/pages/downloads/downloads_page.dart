import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:zplay/models/movie/movie_detail.dart';
import 'package:zplay/models/movie/video.dart';

import '../../models/download/download_task_model.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/download/download_service.dart';
import '../../utils/platform/open_file_location_helper.dart';
import '../../utils/download/download_path_helper.dart';
import '../player/player_screen.dart';
import '../../services/storage/app_image_cache.dart';
import '../../widgets/common/focusable_card.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _playDownloadedMedia(DownloadTask task) {
    final file = File(task.targetFilePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found on disk. It may have been moved or deleted.')),
      );
      return;
    }

    final detail = MovieDetail(
      id: task.mediaId,
      name: task.title,
      type: task.type,
      poster: task.posterUrl,
      background: task.backdropUrl,
      year: task.year,
    );

    Video? episodeVideo;
    if (task.season != null && task.episode != null) {
      episodeVideo = Video(
        id: '${task.mediaId}:${task.season}:${task.episode}',
        title: task.episodeTitle ?? 'Episode ${task.episode}',
        season: task.season ?? 1,
        episode: task.episode ?? 1,
        thumbnail: task.backdropUrl,
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          source: task.toLocalStreamSource(),
          title: task.title,
          detail: detail,
          episode: episodeVideo,
        ),
      ),
    );
  }

  void _confirmDelete(DownloadTask task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Download',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${task.title}" and remove the file from storage?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              DownloadService.instance.deleteDownload(task.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePalette>(
      valueListenable: AppThemeService.currentPalette,
      builder: (context, palette, _) {
        return Scaffold(
          backgroundColor: palette.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: palette.appBarBackgroundColor,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            // No explicit leading: the framework already gates the back button on
            // canPop, so it vanishes in the shell and returns if this page is pushed.
            title: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: palette.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: palette.primaryColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Downloads',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 22),
                tooltip: 'Open Downloads Folder',
                onPressed: () async {
                  final dir = await DownloadPathHelper.getDownloadsDirectoryPath();
                  final opened = await OpenFileLocationHelper.openLocation(dir);
                  if (!opened && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Folder path: $dir')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: ValueListenableBuilder<List<DownloadTask>>(
                valueListenable: DownloadService.instance.tasksNotifier,
                builder: (context, tasks, _) {
                  final activeCount = tasks.where((t) => !t.isCompleted && !t.isFailed).length;
                  final completedCount = tasks.where((t) => t.isCompleted).length;

                  return TabBar(
                    controller: _tabController,
                    indicatorColor: palette.primaryColor,
                    indicatorWeight: 3,
                    labelColor: palette.primaryColor,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: [
                      Tab(text: 'Active ($activeCount)'),
                      Tab(text: 'Downloaded ($completedCount)'),
                    ],
                  );
                },
              ),
            ),
          ),
          body: ValueListenableBuilder<List<DownloadTask>>(
            valueListenable: DownloadService.instance.tasksNotifier,
            builder: (context, tasks, _) {
              final activeTasks = tasks.where((t) => !t.isCompleted).toList();
              final completedTasks = tasks.where((t) => t.isCompleted).toList();

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildActiveList(activeTasks, palette),
                  _buildCompletedList(completedTasks, palette),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildActiveList(List<DownloadTask> tasks, AppThemePalette palette) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'No active downloads',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Media you download from the video player will show up here.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildActiveCard(task, palette);
      },
    );
  }

  Widget _buildActiveCard(DownloadTask task, AppThemePalette palette) {
    final progress = task.progressPercent;
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final isFailed = task.status == DownloadStatus.failed;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardBackgroundColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDownloading
              ? palette.primaryColor.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 50,
                  height: 70,
                  color: const Color(0xFF1E212E),
                  child: task.posterUrl != null && task.posterUrl!.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: task.posterUrl!,
                          cacheManager: AppImageCache.manager,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const Icon(Icons.movie_rounded, color: Colors.white24))
                      : const Icon(Icons.movie_rounded, color: Colors.white24),
                ),
              ),

              const SizedBox(width: 14),

              // Title & Engine Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.primaryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.sourceType == DownloadSourceType.p2p
                                ? 'P2P Torrent'
                                : (task.sourceType == DownloadSourceType.debrid ? 'Cloud Debrid' : 'Direct HTTP'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: palette.primaryColor,
                            ),
                          ),
                        ),
                        if (task.peers > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${task.peers} peers',
                            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isFailed
                          ? 'Failed: ${task.error ?? "Unknown error"}'
                          : isPaused
                              ? 'Paused (${(progress * 100).toStringAsFixed(1)}%)'
                              : '${(progress * 100).toStringAsFixed(1)}% • ${task.speedLabel} • ETA: ${task.etaLabel}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isFailed
                            ? const Color(0xFFEF4444)
                            : (isPaused ? Colors.amber : Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isDownloading)
                    IconButton(
                      icon: const Icon(Icons.pause_circle_rounded, color: Colors.amber, size: 26),
                      tooltip: 'Pause',
                      onPressed: () => DownloadService.instance.pauseDownload(task.id),
                    )
                  else if (isPaused)
                    IconButton(
                      icon: Icon(Icons.play_circle_fill_rounded, color: palette.primaryColor, size: 26),
                      tooltip: 'Resume',
                      onPressed: () => DownloadService.instance.resumeDownload(task.id),
                    )
                  else if (isFailed)
                    IconButton(
                      icon: const Icon(Icons.replay_rounded, color: Colors.orangeAccent, size: 26),
                      tooltip: 'Retry / Reconnect',
                      onPressed: () => DownloadService.instance.resumeDownload(task.id),
                    ),
                  IconButton(
                    icon: Icon(Icons.folder_open_rounded, color: Colors.white.withValues(alpha: 0.6), size: 22),
                    tooltip: 'Open Folder Location',
                    onPressed: () async {
                      final opened = await OpenFileLocationHelper.openLocation(task.targetFilePath);
                      if (!opened && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Folder: ${File(task.targetFilePath).parent.path}')),
                        );
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.4), size: 22),
                    tooltip: 'Cancel',
                    onPressed: () => _confirmDelete(task),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                isFailed
                    ? const Color(0xFFEF4444)
                    : (isPaused ? Colors.amber : palette.primaryColor),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                task.sizeLabel,
                style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.45)),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedList(List<DownloadTask> tasks, AppThemePalette palette) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'No downloaded media',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              'Completed downloads will appear here for offline playback.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.58,
      ),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildCompletedCard(task, palette);
      },
    );
  }

  Widget _buildCompletedCard(DownloadTask task, AppThemePalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.cardBackgroundColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster / Backdrop Thumbnail with Play Trigger
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFF1E212E),
                    child: task.posterUrl != null && task.posterUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: task.posterUrl!,
                            cacheManager: AppImageCache.manager,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.movie_rounded, color: Colors.white24, size: 36),
                            ))
                        : const Center(
                            child: Icon(Icons.movie_rounded, color: Colors.white24, size: 36),
                          ),
                  ),

                  // Gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Center Play Button
                  Center(
                    child: FocusableCard(
                      onTap: () => _playDownloadedMedia(task),
                      builder: (context, state) => Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.primaryColor,
                          boxShadow: [
                            BoxShadow(
                              color: palette.primaryColor.withValues(alpha: 0.5),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),

                  // Open Folder Location (Top-Left)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: FocusableCard(
                      onTap: () async {
                        final opened = await OpenFileLocationHelper.openLocation(task.targetFilePath);
                        if (!opened && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Path: ${task.targetFilePath}')),
                          );
                        }
                      },
                      builder: (context, state) => Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.7),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(Icons.folder_open_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),

                  // Delete Action (Top-Right)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: FocusableCard(
                      onTap: () => _confirmDelete(task),
                      builder: (context, state) => Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.7),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),

                  // File size tag (Bottom-Right)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        DownloadTask.formatBytes(task.totalBytes),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Metadata Row
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.season != null && task.episode != null
                        ? 'S${task.season}:E${task.episode} • Offline'
                        : (task.year != null ? '${task.year} • Offline' : 'Offline Media'),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
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
