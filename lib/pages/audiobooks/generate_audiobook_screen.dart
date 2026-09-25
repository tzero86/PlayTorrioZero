import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../models/audiobook/audiobook_model.dart';
import '../../services/audiobook/custom_audiobook_service.dart';
import '../../services/audiobook/downloaded_epub_detector.dart';
import '../../services/audiobook/epub_cover.dart';
import '../../services/audiobook/epub_splitter.dart';
import '../../services/audiobook/paper2audio_service.dart';
import '../../services/theme/app_theme_service.dart';
import '../../services/theme/design_tokens.dart';
import '../../widgets/common/animated_ambient_background.dart';
import 'audiobook_player_screen.dart';

/// Worker for running EPUB splitting and word analysis off the UI thread via `compute`.
Future<List<EpubPart>> _splitWorker(String path) {
  return EpubSplitter.splitIfNeeded(File(path));
}

class GenerateAudiobookScreen extends StatefulWidget {
  const GenerateAudiobookScreen({super.key});

  @override
  State<GenerateAudiobookScreen> createState() => _GenerateAudiobookScreenState();
}

class _GenerateAudiobookScreenState extends State<GenerateAudiobookScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Paper2AudioService _paperService = Paper2AudioService.instance;
  final CustomAudiobookService _customService = CustomAudiobookService.instance;

  String _selectedVoiceId = 'af_heart';
  bool _isUploading = false;
  Timer? _pollingTimer;

  List<DetectedEpubBook> _detectedEpubs = [];
  bool _isLoadingEpubs = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _paperService.getJobs();
    await _customService.ensureLoaded();
    await _loadDownloadedEpubs();
    if (!mounted) return;
    setState(() {});
    _schedulePolling();
  }

  Future<void> _loadDownloadedEpubs() async {
    setState(() => _isLoadingEpubs = true);
    final epubs = await DownloadedEpubDetector.scanDownloadedEpubs();
    if (mounted) {
      setState(() {
        _detectedEpubs = epubs;
        _isLoadingEpubs = false;
      });
    }
  }

  void _schedulePolling() {
    _pollingTimer?.cancel();
    () async {
      await _paperService.refreshAll();
      if (!mounted) return;
      final hasPending = _paperService.jobs.value.any((j) => !j.isDone && !j.isFailed);
      if (hasPending) {
        _pollingTimer = Timer(const Duration(seconds: 8), _schedulePolling);
      }
    }();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Generation Handlers
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _pickAndUploadEpub() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;
    await _processAndGenerateFromEpub(File(result.files.single.path!));
  }

  Future<void> _processAndGenerateFromEpub(File file) async {
    final tokens = context.tokens;

    setState(() => _isUploading = true);
    try {
      // Analyze and split if oversized (>250k words) on background thread
      final parts = await compute(_splitWorker, file.path);

      // Extract cover image from the original EPUB
      final originalBytes = await file.readAsBytes();
      final rawName = p.basenameWithoutExtension(file.path);
      final safeName = rawName.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final coverPath = await EpubCover.extractAndSave(
        epubBytes: originalBytes,
        saveAsName: '${safeName}_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (parts.length > 1) {
        if (!mounted) return;
        final totalWords = parts.fold<int>(0, (a, p) => a + p.wordCount);
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: tokens.surfaceOverlay,
            shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.mdAll),
            title: Row(
              children: [
                Icon(Icons.call_split_rounded, color: AppThemeService.currentPalette.value.primaryColor),
                const SizedBox(width: 10),
                Text('EPUB Exceeds 250k Words',
                    style: ZplayType.title.copyWith(size: 16).toStyle(color: tokens.textPrimary)),
              ],
            ),
            content: Text(
              'This book has ~${_formatWords(totalWords)} words. It will automatically be split into ${parts.length} parts along chapter boundaries and queued:\n\n'
              '${parts.map((p) => '• ${p.suggestedName} (~${_formatWords(p.wordCount)} words)').join('\n')}',
              style: ZplayType.label.toStyle(color: tokens.textEmphasis),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: ZplayType.label.toStyle(color: tokens.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                  shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Split & Generate',
                    style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary)),
              ),
            ],
          ),
        );

        if (confirm != true) {
          if (mounted) setState(() => _isUploading = false);
          return;
        }
      }

      for (final part in parts) {
        await _paperService.uploadBytes(
          bytes: part.bytes,
          fileName: part.suggestedName,
          voiceId: _selectedVoiceId,
          coverPath: coverPath,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(parts.length == 1
              ? 'Upload complete — AI Audiobook generation started!'
              : 'Uploaded ${parts.length} parts — generation started in background!'),
          backgroundColor: tokens.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _schedulePolling();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Generation failed: $e'), backgroundColor: tokens.danger),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatWords(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}k';
    }
    return n.toString();
  }

  void _playGeneratedAudiobook(GeneratedAudiobookJob job) {
    if (!job.isDone) return;
    final title = job.fileName.replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');
    final streamOrLocalPath = job.localAudioPath ?? job.downloadUrl!;

    final book = Audiobook(
      uuid: 'p2a_${job.runId}',
      audioBookId: 'p2a_${job.runId}',
      dynamicSlugId: job.runId,
      title: title,
      author: 'AI Generated • Kokoro TTS',
      coverImage: job.coverPath ?? '',
      source: 'Paper2Audio AI',
      pageUrl: streamOrLocalPath,
    );

    final chapters = [
      AudiobookChapter(title: title, url: streamOrLocalPath),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudiobookPlayerScreen(
          audiobook: book,
          chapters: chapters,
        ),
      ),
    );
  }

  Future<void> _copyStreamUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stream URL copied to clipboard!'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteGeneratedJob(GeneratedAudiobookJob job) async {
    final tokens = context.tokens;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceOverlay,
        shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.mdAll),
        title: const Text('Remove Generation Job?'),
        content: Text('Remove "${job.fileName}" from the generation list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: ZplayType.label.toStyle(color: tokens.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _paperService.removeJob(job.runId);
      if (mounted) setState(() {});
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Custom Upload Handlers
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _openCustomAudiobookUploadDialog() async {
    final tokens = context.tokens;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4b', 'm4a', 'aac', 'flac', 'opus', 'wav', 'ogg'],
      allowMultiple: true,
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final pickedFiles = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();

    if (pickedFiles.isEmpty || !mounted) return;

    final titleController = TextEditingController(
      text: p.basenameWithoutExtension(pickedFiles.first.path).replaceAll(RegExp(r'[._]'), ' ').trim(),
    );
    final authorController = TextEditingController(text: 'Unknown Author');
    File? pickedCoverFile;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: tokens.surfaceOverlay,
            shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.lgAll),
            title: Row(
              children: [
                Icon(Icons.upload_file_rounded, color: AppThemeService.currentPalette.value.primaryColor),
                const SizedBox(width: 10),
                Text('Add Personal Audiobook',
                    style: ZplayType.title.copyWith(size: 16.5).toStyle(color: tokens.textPrimary)),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected ${pickedFiles.length} audio file(s):',
                      style: ZplayType.bodySmall
                          .copyWith(size: 12.5, weight: FontWeight.w600)
                          .toStyle(color: tokens.textEmphasis),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 90),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        borderRadius: ZplayRadius.smAll,
                        border: Border.all(color: tokens.borderStrong),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: pickedFiles.map((f) => Text(
                          '• ${p.basename(f.path)}',
                          style: ZplayType.caption.copyWith(size: 11.5).toStyle(color: tokens.textSecondary),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      style: ZplayType.body.toStyle(color: tokens.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Audiobook Title',
                        labelStyle: ZplayType.bodySmall.toStyle(color: tokens.textSecondary),
                        filled: true,
                        fillColor: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                        border: const OutlineInputBorder(borderRadius: ZplayRadius.smAll),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: authorController,
                      style: ZplayType.body.toStyle(color: tokens.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Author / Narrator',
                        labelStyle: ZplayType.bodySmall.toStyle(color: tokens.textSecondary),
                        filled: true,
                        fillColor: tokens.textPrimary.withValues(alpha: ZplayOpacity.borderFaint),
                        border: const OutlineInputBorder(borderRadius: ZplayRadius.smAll),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Cover Picker Button
                    Row(
                      children: [
                        if (pickedCoverFile != null)
                          ClipRRect(
                            borderRadius: ZplayRadius.smAll,
                            child: Image.file(pickedCoverFile!, width: 44, height: 44, fit: BoxFit.cover),
                          )
                        else
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: tokens.borderStrong,
                              borderRadius: ZplayRadius.smAll,
                            ),
                            child: Icon(Icons.image_rounded, color: tokens.textMuted),
                          ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.photo_library_rounded, size: 16),
                          label: Text(pickedCoverFile == null ? 'Select Cover Art' : 'Change Cover'),
                          style: TextButton.styleFrom(foregroundColor: AppThemeService.currentPalette.value.primaryColor),
                          onPressed: () async {
                            final imgResult = await FilePicker.platform.pickFiles(
                              type: FileType.image,
                              withData: false,
                            );
                            if (imgResult != null && imgResult.files.single.path != null) {
                              setDlgState(() {
                                pickedCoverFile = File(imgResult.files.single.path!);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: ZplayType.label.toStyle(color: tokens.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppThemeService.currentPalette.value.primaryColor,
                  shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _customService.importAudiobook(
                    audioFiles: pickedFiles,
                    title: titleController.text,
                    author: authorController.text,
                    coverImageFile: pickedCoverFile,
                  );
                  if (mounted) setState(() {});
                },
                child: Text('Import to Library',
                    style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _playUploadedAudiobook(UserUploadedAudiobook book) {
    final audiobook = book.toAudiobookModel();
    final chapters = book.toChapters();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudiobookPlayerScreen(
          audiobook: audiobook,
          chapters: chapters,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // UI Builder
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeService.currentPalette.value;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.bg,
      appBar: AppBar(
        backgroundColor: tokens.bg,
        elevation: 0,
        shape: Border(bottom: tokens.hairline),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.auto_stories_rounded, color: AppThemeService.currentPalette.value.primaryColor, size: 22),
            const SizedBox(width: 10),
            Text('Audiobook Studio & Generator',
                style: ZplayType.title.toStyle(color: tokens.textPrimary)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: palette.primaryColor,
          indicatorWeight: 3,
          labelColor: tokens.textPrimary,
          unselectedLabelColor: tokens.textSecondary,
          labelStyle: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(),
          tabs: const [
            Tab(text: 'AI EPUB Generator (TTS)', icon: Icon(Icons.record_voice_over_rounded, size: 18)),
            Tab(text: 'My Uploaded Audiobooks', icon: Icon(Icons.library_music_rounded, size: 18)),
          ],
        ),
      ),
      body: AnimatedAmbientBackground(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildGeneratorTab(palette),
            _buildUploadedTab(palette),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 1: AI Generator
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildGeneratorTab(AppThemePalette palette) {
    final tokens = context.tokens;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ValueListenableBuilder<List<GeneratedAudiobookJob>>(
          valueListenable: _paperService.jobs,
          builder: (context, jobs, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              physics: const BouncingScrollPhysics(),
              children: [
                // ── Voice Selector Card ──
                _buildVoiceSelectorCard(palette),

                const SizedBox(height: 20),

                // ── Section: Downloaded EPUBs from Books Section ──
                _buildDetectedEpubsSection(palette),

                const SizedBox(height: 20),

                // ── Upload External EPUB File Banner ──
                _buildUploadExternalCard(palette),

                const SizedBox(height: 28),

                // ── Section: Active & Completed Generation Jobs ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'GENERATION QUEUE & COMPLETED (${jobs.length})',
                      style: ZplayType.overline
                          .copyWith(size: 12, weight: FontWeight.w700, letterSpacing: 1.1)
                          .toStyle(color: tokens.textMuted),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, size: 18, color: tokens.textSecondary),
                      tooltip: 'Refresh Status',
                      onPressed: () => _paperService.refreshAll(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (jobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: ZplayRadius.mdAll,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.headphones_rounded, size: 40, color: tokens.textDisabled),
                        const SizedBox(height: 12),
                        Text(
                          'No generated audiobooks yet',
                          style: ZplayType.body
                              .copyWith(weight: FontWeight.w600)
                              .toStyle(color: tokens.textEmphasis),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pick an EPUB above to synthesize high-quality voice narrations.',
                          style: ZplayType.bodySmall.toStyle(color: tokens.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ...jobs.map((job) => _buildJobCard(job, palette)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVoiceSelectorCard(AppThemePalette palette) {
    final tokens = context.tokens;
    final selectedVoice = kPaper2AudioVoices.firstWhere(
      (v) => v.id == _selectedVoiceId,
      orElse: () => kPaper2AudioVoices.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: ZplayRadius.mdAll,
        border: Border.all(color: tokens.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.primaryColor.withValues(alpha: 0.2),
                  borderRadius: ZplayRadius.smAll,
                ),
                child: Icon(Icons.record_voice_over_rounded, color: palette.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Narrator Voice (Kokoro Engine)',
                      style: ZplayType.body
                          .copyWith(size: 14.5, weight: FontWeight.w700)
                          .toStyle(color: tokens.textPrimary),
                    ),
                    Text(
                      selectedVoice.description,
                      style: ZplayType.caption.copyWith(size: 11.5).toStyle(color: tokens.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: ZplayRadius.smAll,
              border: Border.all(color: tokens.borderDefault),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedVoiceId,
                isExpanded: true,
                dropdownColor: tokens.surfaceOverlay,
                icon: Icon(Icons.arrow_drop_down_rounded, color: tokens.textEmphasis),
                items: kPaper2AudioVoices.map((voice) {
                  return DropdownMenuItem<String>(
                    value: voice.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          voice.label,
                          style: ZplayType.label.copyWith(weight: FontWeight.w600).toStyle(color: tokens.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tokens.borderDefault,
                            borderRadius: ZplayRadius.xsAll,
                          ),
                          child: Text(
                            voice.group,
                            style: ZplayType.overline
                                .copyWith(weight: FontWeight.w700)
                                .toStyle(color: tokens.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedVoiceId = val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetectedEpubsSection(AppThemePalette palette) {
    final tokens = context.tokens;

    if (_isLoadingEpubs) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }

    if (_detectedEpubs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DOWNLOADED BOOKS FROM LIBRARY (${_detectedEpubs.length})',
              style: ZplayType.overline
                  .copyWith(size: 12, weight: FontWeight.w700, letterSpacing: 1.1)
                  .toStyle(color: tokens.textMuted),
            ),
            TextButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: Text('Rescan Books', style: ZplayType.caption.toStyle()),
              style: TextButton.styleFrom(foregroundColor: palette.primaryColor),
              onPressed: _loadDownloadedEpubs,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _detectedEpubs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final epub = _detectedEpubs[idx];
              return Container(
                width: 260,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  borderRadius: ZplayRadius.mdAll,
                  border: Border.all(color: tokens.borderDefault),
                ),
                child: Row(
                  children: [
                    // Cover image
                    Container(
                      width: 65,
                      height: 145,
                      decoration: BoxDecoration(
                        color: tokens.borderStrong,
                        borderRadius: ZplayRadius.smAll,
                        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: epub.coverPath != null
                          ? Image.file(File(epub.coverPath!), fit: BoxFit.cover)
                          : Icon(Icons.book_rounded, color: tokens.textDisabled, size: 30),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            epub.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Size: ${(epub.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                            style: ZplayType.caption.toStyle(color: tokens.textMuted),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.record_voice_over_rounded, size: 14),
                            label: Text('Generate',
                                style: ZplayType.bodySmall.copyWith(weight: FontWeight.w700).toStyle()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette.primaryColor,
                              foregroundColor: tokens.onAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                            ),
                            onPressed: _isUploading
                                ? null
                                : () => _processAndGenerateFromEpub(File(epub.filePath)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUploadExternalCard(AppThemePalette palette) {
    final tokens = context.tokens;

    return InkWell(
      onTap: _isUploading ? null : _pickAndUploadEpub,
      borderRadius: ZplayRadius.mdAll,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              palette.primaryColor.withValues(alpha: 0.15),
              tokens.info.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: ZplayRadius.mdAll,
          border: Border.all(color: palette.primaryColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: palette.primaryColor.withValues(alpha: 0.25),
                borderRadius: ZplayRadius.mdAll,
              ),
              child: _isUploading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: tokens.onAccent, strokeWidth: 2.5))
                  : Icon(Icons.upload_file_rounded, color: tokens.onAccent, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isUploading ? 'Analyzing & Uploading Book...' : 'Select External EPUB File',
                    style: ZplayType.subtitle.toStyle(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Pick any .epub file from your device. Large books (>250k words) are auto-split.',
                    style: ZplayType.bodySmall.toStyle(color: tokens.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: tokens.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(GeneratedAudiobookJob job, AppThemePalette palette) {
    final tokens = context.tokens;
    final isDone = job.isDone;
    final isFailed = job.isFailed;
    final cleanTitle = job.fileName.replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');

    Color statusColor;
    String statusLabel;
    if (isDone) {
      statusColor = tokens.success;
      statusLabel = 'Completed';
    } else if (isFailed) {
      statusColor = tokens.danger;
      statusLabel = 'Failed';
    } else {
      statusColor = tokens.warning;
      statusLabel = 'Synthesizing ${(job.progress * 100).round()}%';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: ZplayRadius.mdAll,
        border: Border.all(color: tokens.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cover
              Container(
                width: 48,
                height: 64,
                decoration: BoxDecoration(
                  color: tokens.borderStrong,
                  borderRadius: ZplayRadius.smAll,
                ),
                clipBehavior: Clip.antiAlias,
                child: job.coverPath != null && File(job.coverPath!).existsSync()
                    ? Image.file(File(job.coverPath!), fit: BoxFit.cover)
                    : Icon(Icons.headphones_rounded, color: tokens.textDisabled, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanTitle,
                      style: ZplayType.body.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: ZplayRadius.xsAll,
                            border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 0.8),
                          ),
                          child: Text(
                            statusLabel,
                            style: ZplayType.caption
                                .copyWith(size: 10.5, weight: FontWeight.w700)
                                .toStyle(color: statusColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Voice: ${job.voiceId}',
                          style: ZplayType.caption.toStyle(color: tokens.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Delete Button
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 18, color: tokens.textMuted),
                onPressed: () => _deleteGeneratedJob(job),
              ),
            ],
          ),

          if (!isDone && !isFailed) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: ZplayRadius.xsAll,
              child: LinearProgressIndicator(
                value: job.progress > 0 ? job.progress : null,
                backgroundColor: tokens.borderStrong,
                color: palette.primaryColor,
                minHeight: 5,
              ),
            ),
          ],

          if (isDone) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: Text('Play in App',
                        style: ZplayType.label.copyWith(weight: FontWeight.w700).toStyle()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryColor,
                      foregroundColor: tokens.onAccent,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                    ),
                    onPressed: () => _playGeneratedAudiobook(job),
                  ),
                ),
                const SizedBox(width: 8),
                if (job.downloadUrl != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link_rounded, size: 16),
                    label: const Text('Copy Stream URL'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.textEmphasis,
                      side: BorderSide(color: tokens.textDisabled),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
                    ),
                    onPressed: () => _copyStreamUrl(job.downloadUrl!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tab 2: My Uploaded Audiobooks
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildUploadedTab(AppThemePalette palette) {
    final tokens = context.tokens;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ValueListenableBuilder<List<UserUploadedAudiobook>>(
          valueListenable: _customService.audiobooks,
          builder: (context, books, _) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              physics: const BouncingScrollPhysics(),
              children: [
                // Upload Personal Audiobook Banner
                InkWell(
                  onTap: _openCustomAudiobookUploadDialog,
                  borderRadius: ZplayRadius.mdAll,
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          tokens.success.withValues(alpha: 0.15),
                          tokens.info.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: ZplayRadius.mdAll,
                      border: Border.all(color: tokens.success.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tokens.success.withValues(alpha: 0.2),
                            borderRadius: ZplayRadius.mdAll,
                          ),
                          child: Icon(Icons.library_add_rounded, color: tokens.success, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload Personal Audiobook Files',
                                style: ZplayType.subtitle.toStyle(color: tokens.textPrimary),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Import your own .mp3, .m4b, .m4a, or .flac audiobooks to listen offline.',
                                style: ZplayType.bodySmall.toStyle(color: tokens.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: tokens.textSecondary, size: 24),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'IMPORTED AUDIOBOOKS (${books.length})',
                  style: ZplayType.overline
                      .copyWith(size: 12, weight: FontWeight.w700, letterSpacing: 1.1)
                      .toStyle(color: tokens.textMuted),
                ),
                const SizedBox(height: 10),

                if (books.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tokens.surface,
                      borderRadius: ZplayRadius.mdAll,
                      border: Border.all(color: tokens.borderSubtle),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.library_music_rounded, size: 40, color: tokens.textDisabled),
                        const SizedBox(height: 12),
                        Text(
                          'No personal audiobooks added yet',
                          style: ZplayType.body
                              .copyWith(weight: FontWeight.w600)
                              .toStyle(color: tokens.textEmphasis),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap the banner above to import audio files from your device.',
                          style: ZplayType.bodySmall.toStyle(color: tokens.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ...books.map((b) => _buildUploadedBookCard(b, palette)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUploadedBookCard(UserUploadedAudiobook book, AppThemePalette palette) {
    final tokens = context.tokens;
    final sizeMb = (book.totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: ZplayRadius.mdAll,
        border: Border.all(color: tokens.borderDefault),
      ),
      child: Row(
        children: [
          // Cover
          Container(
            width: 48,
            height: 64,
            decoration: BoxDecoration(
              color: tokens.borderStrong,
              borderRadius: ZplayRadius.smAll,
            ),
            clipBehavior: Clip.antiAlias,
            child: book.coverPath != null && File(book.coverPath!).existsSync()
                ? Image.file(File(book.coverPath!), fit: BoxFit.cover)
                : Icon(Icons.music_note_rounded, color: tokens.textDisabled, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: ZplayType.body.copyWith(weight: FontWeight.w700).toStyle(color: tokens.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${book.author} • ${book.audioFilePaths.length} part(s) ($sizeMb MB)',
                  style: ZplayType.bodySmall.toStyle(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text('Play'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primaryColor,
              foregroundColor: tokens.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.smAll),
            ),
            onPressed: () => _playUploadedAudiobook(book),
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, size: 18, color: tokens.textMuted),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: tokens.surfaceOverlay,
                  shape: const RoundedRectangleBorder(borderRadius: ZplayRadius.mdAll),
                  title: const Text('Delete Audiobook?'),
                  content: Text('Delete "${book.title}" from your library?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Delete', style: ZplayType.label.toStyle(color: tokens.danger)),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await _customService.deleteAudiobook(book.id);
                if (mounted) setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }
}
