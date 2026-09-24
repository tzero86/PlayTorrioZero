import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'package:zplay/models/movie/video.dart';
import 'package:zplay/models/movie/movie_detail.dart';
import 'package:zplay/models/subtitle/subtitle_model.dart';
import 'package:zplay/services/subtitles/subtitle_service.dart';
import 'package:zplay/services/subtitles/subtitle_parser.dart';

import '../../models/stream/stream_model.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/debrid/debrid_service.dart';
import '../../services/stream/torrent_stream_service.dart';
import '../../services/theme/glass_settings.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/simkl/simkl_service.dart';
import '../../services/player/player_settings.dart';
import '../../services/diagnostics/crash_breadcrumbs.dart';
import '../../services/discord/discord_rpc_service.dart';

import '../../widgets/player/player_glass.dart';
import '../../widgets/player/player_top_bar.dart';
import '../../widgets/player/player_transport.dart';
import '../../widgets/player/player_speed_menu.dart';
import '../../services/window/window_service.dart';
import '../../models/player/skip_segment_model.dart';
import '../../services/player/skip_segments_service.dart';
import '../../widgets/player/player_aspect_menu.dart';
import '../../widgets/player/player_audio_menu.dart';
import '../../widgets/player/player_subtitle_menu.dart';
import '../../widgets/player/player_sub_style_modal.dart';
import '../../widgets/player/player_skip_button.dart';
import '../../widgets/player/player_episodes_panel.dart';
import '../../widgets/player/player_sources_panel.dart';
import 'watch_screen.dart';
import '../../widgets/player/player_volume_control.dart';
import '../../widgets/player/sub_sync_bar.dart';
import '../../widgets/player/text_sync_overlay.dart';
import '../../models/download/download_task_model.dart';
import '../../services/download/download_service.dart';
import '../../utils/download/download_path_helper.dart';

class PlayerScreen extends StatefulWidget {
  final StreamSource source;
  final String title;
  final String? backdropUrl;
  final String? logoUrl;
  final MovieDetail? detail;
  final Video? episode;
  final Duration? initialPosition;
  final List<SubtitleVariant>? initialSubtitles;

  const PlayerScreen({
    super.key,
    required this.source,
    required this.title,
    this.backdropUrl,
    this.logoUrl,
    this.detail,
    this.episode,
    this.initialPosition,
    this.initialSubtitles,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with SingleTickerProviderStateMixin {
  late final Player _player = Player(configuration: PlayerSettings.getMediaKitPlayerConfiguration());
  late final mk.VideoController _videoController = mk.VideoController(
    _player,
    configuration: PlayerSettings.getVideoControllerConfiguration(),
  );
  final List<StreamSubscription> _subscriptions = [];

  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration?> _bufferNotifier = ValueNotifier<Duration?>(null);

  bool _isLoading = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration? _buffered;
  bool _wasBuffering = false;
  String _statusMessage = 'Initializing...';
  bool _showControls = true;
  bool _isHoveringUI = false;
  Timer? _hideTimer;
  Timer? _progressSaveTimer;
  DateTime? _lastPointerTimerReset;
  late AnimationController _logoAnimController;

  // Frame Watchdog & Automatic Black Screen Recovery State
  Timer? _frameWatchdogTimer;

  /// Guards the pre-open window. See [_startOpenWatchdog].
  Timer? _openWatchdogTimer;

  /// Times a sustained `player.stream.buffering == true`. See the listener in
  /// initState for why the frame watchdog cannot cover this case.
  Timer? _bufferingStallTimer;

  /// How long buffering may stay latched with no frames before it is treated as
  /// a stalled stream. Generous on purpose: a seek or a slow segment legitimately
  /// buffers for a while, and the overlay is cleared automatically the moment
  /// frames arrive.
  static const Duration _bufferingStallTimeout = Duration(seconds: 25);
  bool _hasFallenBackToSoftware = false;
  bool _hasReceivedFirstVideoFrame = false;

  /// Wall-clock instant playback first reported as playing for the current
  /// stream. Used to detect a stream that stalls before its first frame.
  DateTime? _playbackStartedAt;
  String? _fallbackNoticeText;
  Timer? _fallbackNoticeTimer;

  // Active Menu / Popover
  String? _activeMenu; // 'subtitle' | 'audio' | 'speed' | 'aspect' | 'style' | null
  bool _showSubSyncBar = false;
  bool _showTextSyncOverlay = false;

  // Platform helper
  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // Mobile Lock State
  bool _isLocked = false;
  bool _showUnlockButton = false;
  Timer? _unlockButtonTimer;

  // Visual Brightness & Overlay State (0.0 = pitch black, 1.0 = default 100%, 1.5 = 150% boost)
  double _brightness = 1.0;
  bool _showBrightnessHud = false;
  Timer? _brightnessHudTimer;

  // Touch & Drag Gesture State
  bool _isDraggingBrightness = false;
  bool _isDraggingVolume = false;
  double _dragStartY = 0.0;
  double _dragStartValue = 0.0;

  // Long-Press 2x Speed State
  bool _isFastForwarding = false;
  double _rateBeforeHold = 1.0;
  bool _wasPausedBeforeHold = false;

  Timer? _volumeSaveDebounceTimer;

  // Playback & Audio State
  late double _volume = PlayerSettings.savedVolume.value;
  double _lastVolumeBeforeMute = 1.0;
  bool _isMuted = false;
  bool _showVolumeHud = false;
  Timer? _volumeHudTimer;
  double _playbackRate = 1.0;
  BoxFit _videoFit = BoxFit.contain;
  List<PlayerAudioTrack> _audioTracks = [];
  int _selectedAudioTrackIndex = 0;
  double _audioDelaySec = 0.0;
  bool _showAudioHud = false;
  String _audioHudText = '';
  Timer? _audioHudTimer;
  bool _showAspectHud = false;
  String _aspectHudText = '';
  Timer? _aspectHudTimer;

  // Subtitle State
  List<SubtitleLanguageGroup> _subtitleGroups = [];
  List<PlayerEmbeddedSubtitle> _embeddedSubtitles = [];
  int? _selectedEmbeddedSubtitleIndex;
  SubtitleVariant? _currentSubtitleVariant;
  bool _isSubtitleEnabled = false;
  String? _currentSubtitlePath;
  List<SubCue> _currentCues = [];
  SubFormat _currentSubFormat = SubFormat.srt;
  double _subtitleDelayMs = 0;
  double _subtitleScale = 1.0;

  // Skip Segments State (IntroDB)
  List<MediaSkipSegment> _skipSegments = [];
  MediaSkipSegment? _activeSkipSegment;
  bool _showSkipButton = false;
  final Set<String> _dismissedSegmentKeys = {};

  // Episodes & Sources Side Panels State
  late StreamSource _currentSource;
  Video? _currentEpisode;
  late String _currentTitle;
  bool _showEpisodesPanel = false;
  bool _showSourcesPanel = false;
  Video? _sourcesEpisode;
  String? _sourcesErrorMessage;

  /// True once the startup-stall detector gives up on the current source. Drives
  /// an actionable "choose another source" overlay instead of a bare spinner, so
  /// the user is never told to pick another source without the means to.
  bool _streamStalled = false;
  final Map<String, List<StreamSource>> _cachedSourcesByEpisode = {};
  String? _activeStreamUrl;

  /// Headers the active network stream was opened with. The black-screen
  /// watchdog's recovery path must reuse these: several built-in providers
  /// gate their URLs on Referer/Origin and answer 403 without them.
  Map<String, String>? _activeHttpHeaders;

  /// Playback offset the current stream was opened at. The watchdog measures
  /// elapsed playback against this rather than the absolute position, because
  /// on a resume the position already exceeds its 2.5s threshold the instant
  /// playback starts - which fired the fallback before the decoder could
  /// deliver a first frame.
  Duration _positionAtStreamOpen = Duration.zero;

  bool _wasFullscreenBeforeEntering = false;

  @override
  void initState() {
    super.initState();
    CrashBreadcrumbs.stream('start', title: widget.title);
    _wasFullscreenBeforeEntering = WindowService.instance.isFullscreen;
    _currentSource = widget.source;
    _currentEpisode = widget.episode;
    _currentTitle = widget.title;
    _volume = PlayerSettings.savedVolume.value;
    _isMuted = _volume == 0;

    if (widget.initialSubtitles != null && widget.initialSubtitles!.isNotEmpty) {
      _loadSourceSubtitles(widget.initialSubtitles!);
    }
    if (_currentSource.subtitles != null && _currentSource.subtitles!.isNotEmpty) {
      _loadSourceSubtitles(_currentSource.subtitles!);
    }

    WakelockPlus.enable();
    _logoAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    PlayerSettings.changeNotifier.addListener(_onPlayerSettingsChanged);

    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        if (playing) {
          _playbackStartedAt ??= DateTime.now();
        }
        if (mounted) {
          setState(() => _isPlaying = playing);
          _updateDiscordRpc(isPaused: !playing);
        }
      }),
      _player.stream.position.listen((pos) {
        _position = pos;
        _positionNotifier.value = pos;
        _onPlaybackTick(pos);
      }),
      _player.stream.duration.listen((dur) {
        if (mounted) {
          setState(() => _duration = dur);
          _updateDiscordRpc();
        }
      }),
      _player.stream.buffer.listen((buf) {
        _buffered = buf;
        _bufferNotifier.value = buf;
      }),
      _player.stream.buffering.listen((isBuffering) {
        if (_wasBuffering && !isBuffering && PlayerSettings.autoResyncOnStall.value) {
          try {
            if (PlayerSettings.hardwareAudioClock.value) {
              final np = _player.platform as dynamic;
              np.setProperty('video-sync', 'audio');
            }
          } catch (_) {}
        }
        // Sustained buffering is the latched runtime signal for a stream that is
        // not delivering data, and nothing else times it. The frame watchdog's
        // conditions all require a missing first frame AND a zero video width, so
        // a stream that latches buffering with a known width slips through every
        // guard and sits there indefinitely. Time the false->true edge instead.
        if (isBuffering && !_wasBuffering) {
          _bufferingStallTimer?.cancel();
          _bufferingStallTimer = Timer(_bufferingStallTimeout, () {
            if (!mounted || _hasReceivedFirstVideoFrame || _streamStalled) return;
            CrashBreadcrumbs.stream('buffering.stall', title: _currentTitle);
            setState(() {
              _isLoading = true;
              _streamStalled = true;
              _statusMessage =
                  'This stream is not responding - the source may be expired.';
            });
          });
        } else if (!isBuffering && _wasBuffering) {
          _bufferingStallTimer?.cancel();
          _bufferingStallTimer = null;
        }
        _wasBuffering = isBuffering;
      }),
      // Per-stream "video is flowing" signal.
      //
      // VideoController.waitUntilFirstFrameRendered is backed by a single
      // Completer that is created once per controller and never reset, so after
      // the first stream it is already complete: re-registering on it marked
      // frames as received the instant a NEW stream started, which made every
      // stall condition unsatisfiable and permanently disabled the watchdog for
      // the second and later streams - exactly the path taken when the user
      // follows the app's own "Choose another source" advice.
      //
      // The width stream fires per stream instead, and _initStream resets the
      // flag each time.
      _player.stream.width.listen((width) {
        if (!mounted || _hasReceivedFirstVideoFrame) return;
        if (width != null && width > 0) {
          _hasReceivedFirstVideoFrame = true;
          debugPrint('[PlayerWatchdog] Video parameters received (${width}px wide).');
          _clearStallOverlay();
        }
      }),
      _player.stream.tracks.listen((tracks) {
        _updateMediaTracks(tracks);
      }),
      _player.stream.track.listen((track) {
        if (!mounted) return;
        final aid = track.audio.id;
        final idx = int.tryParse(aid);
        if (idx != null && _selectedAudioTrackIndex != idx) {
          setState(() => _selectedAudioTrackIndex = idx);
        }
      }),
      _player.stream.error.listen((error) {
        _onControllerError(error);
      }),
      _player.stream.completed.listen((completed) {
        if (completed && mounted) {
          _savePlaybackProgress();
        }
      }),
    ]);

    _initStream();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _initStream() async {
    _hasFallenBackToSoftware = false;
    _hasReceivedFirstVideoFrame = false;
    _playbackStartedAt = null;
    _startOpenWatchdog();
    _bufferingStallTimer?.cancel();
    _bufferingStallTimer = null;
    String? streamUrl;

    print('[PlayerScreen] Initializing playback:');
    print('[PlayerScreen]   Title: $_currentTitle');
    print('[PlayerScreen]   Source Name: ${_currentSource.name}');
    print('[PlayerScreen]   Addon Name: ${_currentSource.addonName}');
    print('[PlayerScreen]   Source Title: ${_currentSource.title}');
    print('[PlayerScreen]   Raw URL: ${_currentSource.url}');

    try {
      final rawUrl = _currentSource.url;

      // Handle offline downloaded file playback directly
      if (rawUrl != null && (File(rawUrl).existsSync() || _currentSource.name == 'Downloaded')) {
        print('[PlayerScreen] Initializing offline local file playback: $rawUrl');
        _activeStreamUrl = rawUrl;
        await PlayerSettings.applyPreOpenProperties(_player);
        await _player.open(Media(rawUrl), play: true);
        await PlayerSettings.applyPostOpenProperties(_player);
        _setSubtitleScale(_subtitleScale);
        _applyVolume(_isMuted ? 0.0 : _volume);
        _startFrameWatchdog();
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final infoHash = _currentSource.infoHash;
      final isMagnetUrl = rawUrl != null && rawUrl.startsWith('magnet:');
      final isTorrent = (infoHash != null && infoHash.isNotEmpty) || isMagnetUrl;

      if (isTorrent) {
        String magnet;
        if (isMagnetUrl) {
          magnet = rawUrl;
        } else {
          magnet = 'magnet:?xt=urn:btih:$infoHash';
          if (_currentSource.sources != null) {
            for (final source in _currentSource.sources!) {
              if (source.startsWith('tracker:')) {
                final trackerUrl = source.replaceFirst('tracker:', '');
                magnet += '&tr=${Uri.encodeComponent(trackerUrl)}';
              }
            }
          }
        }

        final useDebrid = await DebridService().isDebridActiveForStreams();
        final seasonNum = _currentEpisode?.season;
        final episodeNum = _currentEpisode?.episode;
        final epTitle = _currentEpisode?.title;

        if (useDebrid) {
          final activeService = await DebridService().getSelectedService();
          if (!mounted) return;
          setState(() => _statusMessage = 'Using $activeService for files...');

          final debridFiles = await DebridService().resolveMagnet(
            magnet: magnet,
            fileIndex: _currentSource.fileIdx,
            filename: _currentTitle,
            season: seasonNum,
            episode: episodeNum,
            episodeTitle: epTitle,
          );

          if (debridFiles.isEmpty || debridFiles.first.downloadUrl.isEmpty) {
            throw Exception('$activeService returned no direct stream links.');
          }

          streamUrl = debridFiles.first.downloadUrl;
          print('[PlayerScreen] Debrid resolved stream URL: $streamUrl');
        } else {
          if (!mounted) return;
          setState(() => _statusMessage = 'Gathering metadata & peers...');

          streamUrl = await TorrentStreamService().streamTorrent(
            magnet,
            season: seasonNum,
            episode: episodeNum,
            episodeTitle: epTitle,
            fileIdx: _currentSource.fileIdx,
          );
        }
      } else if (rawUrl != null && rawUrl.isNotEmpty) {
        streamUrl = rawUrl;
      } else {
        throw Exception('No valid stream source found.');
      }

      if (streamUrl == null) throw Exception('Stream URL is null');

      final sanitizedUrlStr = streamUrl.contains('::')
          ? streamUrl.replaceAll('::', '%3A%3A')
          : streamUrl;

      // Automatically resolve complete CDN headers (Referer, Origin, User-Agent)
      final playerHeaders = PlayerSettings.resolveStreamHeaders(
        sanitizedUrlStr,
        _currentSource.headers,
      );

      // Also merge any proxyHeaders from behaviorHints if present
      final proxyReqHeaders = _currentSource.behaviorHints?['proxyHeaders']?['request'];
      if (proxyReqHeaders is Map) {
        playerHeaders.addAll(Map<String, String>.from(proxyReqHeaders));
      }

      final cleanUri = Uri.parse(sanitizedUrlStr);
      _activeStreamUrl = sanitizedUrlStr;
      print('[PlayerScreen] Opening direct network stream URL: $cleanUri (headers: ${playerHeaders.keys})');

      if (!mounted) return;
      final epLabel = _currentEpisode != null
          ? 'S${_currentEpisode!.season ?? 1}:E${_currentEpisode!.episode ?? 1} - ${_currentEpisode!.title.isNotEmpty ? _currentEpisode!.title : "Episode ${_currentEpisode!.episode ?? 1}"}'
          : (widget.detail?.name ?? _currentTitle);
      setState(() => _statusMessage = 'Buffering $epLabel...');

      final lowerClean = sanitizedUrlStr.toLowerCase();
      final bool isLive = _currentSource.behaviorHints?['isLive'] == true ||
          _currentSource.addonName.toLowerCase() == 'iptv' ||
          _currentSource.name?.toLowerCase() == 'iptv' ||
          lowerClean.contains('/live/') ||
          lowerClean.contains('/hls/live');

      final bool isTorrentStream = isTorrent ||
          sanitizedUrlStr.contains(':8090') ||
          sanitizedUrlStr.contains('/stream?link=') ||
          sanitizedUrlStr.contains('/stream?');

      await PlayerSettings.applyPreOpenProperties(_player, isLive: isLive, isTorrent: isTorrentStream);

      // Set native MPV properties for referer and user-agent directly on the player for web streams
      if (!isTorrentStream) {
        try {
          final dynamic platform = _player.platform;
          if (platform != null) {
            final referer = playerHeaders['Referer'] ?? playerHeaders['referer'];
            if (referer != null && referer.isNotEmpty) {
              await platform.setProperty('referrer', referer);
            }
            final ua = playerHeaders['User-Agent'] ?? playerHeaders['user-agent'];
            if (ua != null && ua.isNotEmpty) {
              await platform.setProperty('user-agent', ua);
            }
          }
        } catch (e) {
          print('[PlayerScreen] Warning setting native header properties: $e');
        }
      }

      _activeHttpHeaders = isTorrentStream ? null : Map<String, String>.from(playerHeaders);
      _positionAtStreamOpen = widget.initialPosition ?? Duration.zero;

      // Breadcrumbs around open(): there was previously no stream event recorded
      // between "about to open" and playback, so an incident inside the player
      // left no trail at all - which is why a hung open looked like nothing
      // happened.
      CrashBreadcrumbs.stream('open.start', title: _currentTitle);
      await _player.open(
        Media(
          cleanUri.toString(),
          httpHeaders: isTorrentStream ? null : playerHeaders,
          start: widget.initialPosition,
        ),
        play: true,
      );
      CrashBreadcrumbs.stream('open.ok', title: _currentTitle);
      _cancelOpenWatchdog();

      await PlayerSettings.applyPostOpenProperties(_player);

      _setSubtitleScale(_subtitleScale);
      _applyVolume(_isMuted ? 0.0 : _volume);

      print('[PlayerScreen SUCCESS] Player opened media successfully for $streamUrl');

      _updateMediaTracks(_player.state.tracks);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      _player.play();
      _startFrameWatchdog();
      _startHideControlsTimer();

      // Defer background services until after playback starts
      Future.microtask(() {
        if (!mounted) return;
        _fetchSkipSegments();
        _fetchInitialSubtitles();

        final detail = widget.detail;
        if (detail != null) {
          final isColl = detail.isCollection;
          final targetId = (_currentEpisode != null && _currentEpisode!.id.startsWith('tt'))
              ? _currentEpisode!.id
              : (detail.id.startsWith('tt') ? detail.id : (detail.tmdbId ?? detail.id));
          if (targetId.isNotEmpty) {
            final s = isColl ? null : _currentEpisode?.season;
            final e = isColl ? null : _currentEpisode?.episode;
            final initPos = widget.initialPosition?.inSeconds ?? 0;
            final dur = _player.state.duration.inSeconds;
            final progress = (dur > 0 ? (initPos / dur) * 100.0 : 0.0).clamp(0.0, 100.0);

            TraktService.instance.isAuthenticated().then((authed) {
              if (authed) {
                TraktService.instance.scrobbleStart(targetId, progress, season: s, episode: e);
              }
            });
            SimklService.instance.isAuthenticated().then((authed) {
              if (authed) {
                SimklService.instance.scrobbleStart(targetId, progress, season: s, episode: e);
              }
            });
          }
        }
      });

      _progressSaveTimer?.cancel();
      _progressSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        _savePlaybackProgress();
      });
    } catch (e, stackTrace) {
      _cancelOpenWatchdog();
      CrashBreadcrumbs.error(e, context: 'PlayerScreen.initStream $_currentTitle');
      print('[PlayerScreen ERROR] Failed to initialize stream URL: "$streamUrl"');
      print('[PlayerScreen ERROR] Exception: $e');
      print('[PlayerScreen ERROR] StackTrace:\n$stackTrace');

      if (!mounted) return;

      // If we have an episode context (TV show), reopen the sources panel with error notice!
      if (_currentEpisode != null && widget.detail?.videos.isNotEmpty == true) {
        setState(() {
          _isLoading = false;
          _showSourcesPanel = true;
          _sourcesEpisode = _currentEpisode;
          _sourcesErrorMessage = 'Source failed to play. Please select another source below.';
        });
        return;
      }

      String displayMessage = 'Error: $e';
      if (e is PlatformException &&
          (e.message?.contains('invalid or unsupported media') ?? false)) {
        displayMessage =
            'Media Open Error: Stream server quota exceeded or invalid media format.\nPlease select another stream.';
      }

      setState(() {
        _statusMessage = displayMessage;
      });
    }
  }

  /// A one-shot guard over the window between "about to open" and "opened".
  ///
  /// `_isLoading` renders the "Buffering <title>..." spinner and is cleared ONLY
  /// on the success path, after `await _player.open(...)` returns - and that call
  /// has no timeout. Every other watchdog in this class is started *after* open
  /// returns, so a hung `open()` used to leave the user on an infinite spinner
  /// with no timer running, no error and no way out. This timer is independent of
  /// that await, so it fires even when open() never completes, and it raises the
  /// same actionable overlay the stall detector uses (Choose another source /
  /// Go back) instead of a silent spin.
  void _startOpenWatchdog() {
    _openWatchdogTimer?.cancel();
    _openWatchdogTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted || !_isLoading || _hasReceivedFirstVideoFrame) return;
      CrashBreadcrumbs.stream('open.timeout', title: _currentTitle);
      setState(() {
        // Keep the overlay up; _streamStalled swaps the spinner for the message
        // and the escape actions.
        _isLoading = true;
        _streamStalled = true;
        _statusMessage = 'This stream is not responding - the source may be expired.';
      });
    });
  }

  void _cancelOpenWatchdog() {
    _openWatchdogTimer?.cancel();
    _openWatchdogTimer = null;
  }

  void _startFrameWatchdog() {
    _frameWatchdogTimer?.cancel();
    if (!PlayerSettings.autoRecoverBlackScreen.value) return;

    // Listen to first frame rendered directly from VideoController
    // Deliberately NOT registering waitUntilFirstFrameRendered here. Its backing
    // Completer is one-shot per VideoController and never reset, so on the 2nd+
    // stream it completes instantly and falsely marks frames as received, which
    // disables every stall condition below. _hasReceivedFirstVideoFrame is fed
    // by the per-stream width subscription in initState instead.

    _frameWatchdogTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // If video frames are verified or width/height are populated, we have frames!
      if (_hasReceivedFirstVideoFrame || (_player.state.width != null && _player.state.width! > 0)) {
        _hasReceivedFirstVideoFrame = true;
        _clearStallOverlay();
        if (_player.state.width != null && _player.state.width! > 0) {
          timer.cancel();
          return;
        }
      }

      // Black screen watchdog condition:
      // Audio is actively playing past 2.5 seconds, but video width is null or 0 and no frame has rendered
      // Elapsed playback, not absolute position: on a resume the position is
      // already past 2.5s when playback starts, which would fire this before the
      // decoder has had a chance to deliver a first frame.
      final bool hasPlayedPastGrace =
          (_position - _positionAtStreamOpen) > const Duration(milliseconds: 2500);

      final bool isAudioGhosting = _isPlaying &&
          hasPlayedPastGrace &&
          !_hasReceivedFirstVideoFrame &&
          (_player.state.width == null || _player.state.width == 0);

      // A valid playlist that never delivers data leaves the player open with no
      // frames AND no progress at all, so the audio-ghosting check above can never
      // fire. Catch that separately: still no first frame and the position has not
      // moved at all some seconds after playback nominally started.
      final bool stalledAtStartup = _isPlaying &&
          _playbackStartedAt != null &&
          DateTime.now().difference(_playbackStartedAt!) > const Duration(seconds: 12) &&
          !_hasReceivedFirstVideoFrame &&
          (_player.state.width == null || _player.state.width == 0) &&
          (_position - _positionAtStreamOpen).abs() < const Duration(seconds: 1);

      if ((isAudioGhosting || stalledAtStartup) && !_hasFallenBackToSoftware) {
        timer.cancel();
        _triggerSoftwareFallback(
          reason: stalledAtStartup
              ? 'Stream stalled with no frames or progress (not delivering data)'
              : 'Audio playing without video frames (decoder deadlock)',
        );
      }
    });
  }

  /// Clears the stall/loading overlay once frames actually render. The stall
  /// detector raises it optimistically, so leaving it up over playing video
  /// would tell the user the stream failed while they are watching it.
  void _clearStallOverlay() {
    _cancelOpenWatchdog();
    _bufferingStallTimer?.cancel();
    _bufferingStallTimer = null;
    if (!mounted || !_isLoading) return;
    setState(() {
      _isLoading = false;
      _streamStalled = false;
      _statusMessage = '';
    });
  }

  Future<void> _triggerSoftwareFallback({required String reason}) async {
    if (_hasFallenBackToSoftware) return;
    _hasFallenBackToSoftware = true;

    debugPrint('[PlayerWatchdog] TRIGGERING AUTOMATIC FALLBACK TO SOFTWARE DECODING: $reason');

    if (mounted) {
      setState(() {
        _fallbackNoticeText = '⚠️ Black screen detected • Switched to Software Mode';
      });
      _fallbackNoticeTimer?.cancel();
      _fallbackNoticeTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _fallbackNoticeText = null);
      });
    }

    final success = await PlayerSettings.fallbackToSoftware(_player);
    if (!success || (_player.state.width == null || _player.state.width == 0)) {
      debugPrint('[PlayerWatchdog] Re-syncing stream with software decoding...');
      if (_activeStreamUrl != null && mounted) {
        try {
          final resumePos = _position > Duration.zero ? _position : _player.state.position;
          final platform = _player.platform as dynamic;
          await platform?.setProperty('hwdec', 'no');
          await platform?.setProperty('glsl-shaders', '');
          await platform?.setProperty('vid', 'auto');
          await _player.open(
            Media(
              _activeStreamUrl!,
              httpHeaders: _activeHttpHeaders,
              start: resumePos,
            ),
            play: true,
          );
        } catch (e) {
          debugPrint('[PlayerWatchdog] Reload error during fallback: $e');
        }
      }
    }

    // The recovery above is best-effort (a dead provider URL cannot be revived).
    // Never leave the user staring at a black screen with no explanation, and
    // never tell them to pick another source without giving them the means to.
    await Future<void>.delayed(const Duration(seconds: 8));
    if (mounted && (_player.state.width == null || _player.state.width == 0)) {
      setState(() {
        // _statusMessage is only drawn inside the `if (_isLoading)` overlay, and
        // _isLoading was cleared when the (valid but dataless) playlist opened.
        // Re-show that overlay so the message is actually visible to the user.
        _isLoading = true;
        _streamStalled = true;
        _statusMessage =
            'This stream is not responding - the source may be expired.';
      });
    }
  }

  /// Opens the canonical source picker for this title.
  ///
  /// Prefers the in-player [PlayerSourcesPanel] so a stalled stream can be
  /// swapped without leaving the player - it is provider-scoped, so the
  /// alternative sources of the same provider are right there. Movies are
  /// served too: the panel is handed a stand-in [Video] built from the detail.
  /// Only when no target exists (no detail and no episode) does this fall back
  /// to leaving the player for [WatchScreen], the app's full source-selection
  /// surface. Without this the user is told to pick another source with no way
  /// to do so, and the Continue Watching tile re-resumes the same dead source
  /// forever.
  void _openSourcePicker() {
    final detail = widget.detail;
    final target = _sourcesTarget;
    if (target != null) {
      setState(() {
        _isLoading = false;
        _streamStalled = false;
        _statusMessage = '';
        _sourcesEpisode = target;
        _sourcesErrorMessage = 'This stream is not responding - the source may be expired. Pick another source below.';
        _showSourcesPanel = true;
      });
      return;
    }
    if (detail == null) return;
    final position = _position > Duration.zero ? _position : _player.state.position;
    _progressSaveTimer?.cancel();
    _frameWatchdogTimer?.cancel();
    _cancelOpenWatchdog();
    _bufferingStallTimer?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => WatchScreen(
          detail: detail,
          selectedEpisode: _currentEpisode,
          type: detail.type,
          initialPosition: position,
        ),
      ),
    );
  }

  void _updateMediaTracks(Tracks tracks) {
    if (!mounted) return;

    // Ensure video track is active if present
    final videoTracks = tracks.video;
    if (videoTracks.isNotEmpty) {
      final activeVid = _player.state.track.video.id;
      if (activeVid == 'no') {
        debugPrint('[PlayerScreen] Video track was disabled. Re-enabling video track auto...');
        try {
          final dynamic platform = _player.platform;
          platform?.setProperty('vid', 'auto');
        } catch (_) {}
      }
    }

    final audioList = tracks.audio;
    final audioTracks = <PlayerAudioTrack>[];
    for (int i = 0; i < audioList.length; i++) {
      final t = audioList[i];
      if (t.id == 'no' || t.id == 'auto') continue;
      final lang = t.language;
      final title = t.title ?? (lang != null ? lang.toUpperCase() : 'Track ${i + 1}');
      final idx = int.tryParse(t.id) ?? (i + 1);
      audioTracks.add(PlayerAudioTrack(
        index: idx,
        title: title,
        language: lang,
        channels: int.tryParse(t.channels?.toString() ?? ''),
      ));
    }

    final subList = tracks.subtitle;
    final embeddedSubs = <PlayerEmbeddedSubtitle>[];
    for (int i = 0; i < subList.length; i++) {
      final t = subList[i];
      if (t.id == 'no' || t.id == 'auto') continue;
      final lang = t.language;
      final title = t.title ?? (lang != null ? lang.toUpperCase() : 'Track ${i + 1}');
      final idx = int.tryParse(t.id) ?? (i + 1);
      embeddedSubs.add(PlayerEmbeddedSubtitle(
        index: idx,
        title: title,
        language: lang,
      ));
    }

    int activeIdx = _selectedAudioTrackIndex;
    if (activeIdx == 0 && audioTracks.isNotEmpty) {
      final activeAid = _player.state.track.audio.id;
      activeIdx = int.tryParse(activeAid) ?? audioTracks.first.index;
    }

    setState(() {
      _audioTracks = audioTracks;
      _embeddedSubtitles = embeddedSubs;
      if (_selectedAudioTrackIndex == 0 && audioTracks.isNotEmpty) {
        _selectedAudioTrackIndex = activeIdx;
      }
    });
  }

  static String cleanMediaTitle(String raw) {
    var name = raw;
    name = name.replaceAll(RegExp(r'\.(mkv|mp4|avi|webm|ts|mov|m4v|srt|vtt)$', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'[._]'), ' ');
    name = name.replaceAll(RegExp(r'\b(2160p|1080p|720p|480p|4k|uhd|ds4k|webrip|web-dl|bluray|brrip|h264|x264|h265|x265|hevc|10bit|ddp5\.1|dd5\.1|atmos|aac|ac3|dts|flac|remux|hdr|dv|proper|repack|hdtv)\b', caseSensitive: false), ' ');
    name = name.replaceAll(RegExp(r'-[a-zA-Z0-9]+$'), '');
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _fetchInitialSubtitles() async {
    try {
      int? searchYear;
      if (widget.detail?.year != null && widget.detail!.year!.isNotEmpty) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(widget.detail!.year!);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final rawName = widget.detail?.name ?? widget.title;
      if (searchYear == null) {
        final yMatch = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(rawName);
        if (yMatch != null) searchYear = int.tryParse(yMatch.group(1)!);
      }
      final isColl = widget.detail?.isCollection == true;
      final targetImdbId = (_currentEpisode != null && _currentEpisode!.id.startsWith('tt'))
          ? _currentEpisode!.id
          : widget.detail?.id;
      final targetName = (isColl && _currentEpisode != null && _currentEpisode!.title.isNotEmpty)
          ? _currentEpisode!.title
          : rawName;
      final targetYear = (isColl && _currentEpisode?.released != null && _currentEpisode!.released!.length >= 4)
          ? int.tryParse(_currentEpisode!.released!.substring(0, 4))
          : searchYear;
      final targetSeason = isColl ? null : _currentEpisode?.season;
      final targetEpisode = isColl ? null : _currentEpisode?.episode;
      final showName = cleanMediaTitle(targetName);

      print('[PlayerScreen] Scraping initial subtitles for "$showName" (year: $targetYear, imdb: $targetImdbId)...');

      await for (final batch in SubtitleService().streamSubtitles(
        showName,
        imdbId: targetImdbId,
        season: targetSeason,
        episode: targetEpisode,
        year: targetYear,
      )) {
        if (!mounted || batch.isEmpty) continue;
        final newGroups = SubtitleService.groupVariantsByLanguage(batch);
        setState(() => _subtitleGroups = _mergeSubtitleGroups(_subtitleGroups, newGroups));

        // Auto-load matching language subtitle for the new episode if subtitles were enabled and none loaded yet
        if (_isSubtitleEnabled && _currentSubtitleVariant != null && _currentSubtitlePath == null) {
          final previousLang = _currentSubtitleVariant!.language.toLowerCase();
          final matchingGroup = _subtitleGroups.firstWhere(
            (g) => g.language.toLowerCase() == previousLang,
            orElse: () => _subtitleGroups.firstWhere(
              (g) => g.language.toLowerCase().contains('english') || g.language.toLowerCase() == 'en',
              orElse: () => _subtitleGroups.first,
            ),
          );
          if (matchingGroup.variants.isNotEmpty) {
            _loadSubtitle(matchingGroup.variants.first);
          }
        }
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error loading subtitles: $e');
    }
  }

  void _loadSourceSubtitles(List<SubtitleVariant> subs) {
    if (subs.isEmpty) return;
    final Map<String, List<SubtitleVariant>> grouped = {};
    for (final s in subs) {
      grouped.putIfAbsent(s.language, () => []).add(s);
    }
    final sourceGroups = grouped.entries.map((e) {
      return SubtitleLanguageGroup(language: e.key, variants: e.value);
    }).toList();
    _subtitleGroups = _mergeSubtitleGroups(_subtitleGroups, sourceGroups);
    debugPrint('[PlayerScreen] Loaded ${subs.length} direct stream subtitles across ${sourceGroups.length} language groups');
  }

  static List<SubtitleLanguageGroup> _mergeSubtitleGroups(
    List<SubtitleLanguageGroup> existing,
    List<SubtitleLanguageGroup> incoming,
  ) {
    final Map<String, List<SubtitleVariant>> map = {};
    for (final g in existing) {
      map.putIfAbsent(g.language, () => []).addAll(g.variants);
    }
    for (final g in incoming) {
      final list = map.putIfAbsent(g.language, () => []);
      for (final v in g.variants) {
        if (!list.any((existingV) => existingV.downloadUrl == v.downloadUrl)) {
          list.add(v);
        }
      }
    }
    final sortedKeys = map.keys.toList()..sort((a, b) => a.compareTo(b));
    return sortedKeys.map((lang) => SubtitleLanguageGroup(language: lang, variants: map[lang]!)).toList();
  }

  void _startHideControlsTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted &&
          _isPlaying &&
          !_isHoveringUI &&
          _activeMenu == null &&
          !_showSubSyncBar &&
          !_showTextSyncOverlay) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_showTextSyncOverlay || _activeMenu != null) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideControlsTimer();
  }

  void _handlePointerActivity() {
    if (_isLoading) return;
    if (!_showControls) setState(() => _showControls = true);

    final now = DateTime.now();
    if (_lastPointerTimerReset == null ||
        now.difference(_lastPointerTimerReset!) >= const Duration(milliseconds: 250)) {
      _lastPointerTimerReset = now;
      _startHideControlsTimer();
    }
  }

  void _toggleMenu(String menuName) {
    setState(() {
      if (_activeMenu == menuName) {
        _activeMenu = null;
        _startHideControlsTimer();
      } else {
        _activeMenu = menuName;
        _showSubSyncBar = false;
        _showTextSyncOverlay = false;
        _hideTimer?.cancel();
      }
    });
  }

  void _selectEmbeddedSubtitle(PlayerEmbeddedSubtitle embedded) {
    SubtitleService().deleteSubtitleFile(_currentSubtitlePath);
    setState(() {
      _selectedEmbeddedSubtitleIndex = embedded.index;
      _currentSubtitleVariant = SubtitleVariant(
        providerName: 'Embedded',
        language: embedded.language ?? 'Embedded',
        title: embedded.title,
        downloadUrl: '',
        format: 'ass',
      );
      _isSubtitleEnabled = true;
      _currentSubtitlePath = null;
      _currentCues = [];
    });

    _player.setSubtitleTrack(SubtitleTrack(embedded.index.toString(), embedded.title, embedded.language));
    _setSubtitleScale(_subtitleScale);
    PlayerSettings.applySubtitleStyling(_player);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to embedded subtitle: ${embedded.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _disableSubtitles() {
    SubtitleService().deleteSubtitleFile(_currentSubtitlePath);
    setState(() {
      _isSubtitleEnabled = false;
      _currentSubtitleVariant = null;
      _selectedEmbeddedSubtitleIndex = null;
      _currentSubtitlePath = null;
      _currentCues = [];
    });
    _player.setSubtitleTrack(SubtitleTrack.no());
  }

  Future<void> _loadSubtitle(SubtitleVariant variant) async {
    SubtitleService().deleteSubtitleFile(_currentSubtitlePath);
    _currentSubtitleVariant = variant;
    _selectedEmbeddedSubtitleIndex = null;
    _isSubtitleEnabled = true;
    _player.setSubtitleTrack(SubtitleTrack.no());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${variant.language} subtitle...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final path = await SubtitleService().downloadSubtitle(variant);
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download subtitle')),
        );
      }
      return;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final content = SubtitleParser.decodeBytesWithFallback(bytes);
        final parseResult = SubtitleParser.parse(content);
        _currentCues = parseResult.cues;
        _currentSubFormat = parseResult.format;
      }
    } catch (e) {
      print('[PlayerScreen] Subtitle cues parse error: $e');
    }

    _currentSubtitlePath = path;
    final resolvedUri = _resolveSubtitleUri(path);
    _player.setSubtitleTrack(SubtitleTrack.uri(resolvedUri, title: variant.language));
    _setSubtitleScale(_subtitleScale);
    PlayerSettings.applySubtitleStyling(_player);

    if (_subtitleDelayMs != 0) {
      await _applyLiveDelay(_subtitleDelayMs / 1000.0);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${variant.language} subtitle loaded (${_currentCues.length} lines)'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _resolveSubtitleUri(String pathOrUrl) {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return pathOrUrl;
    }
    try {
      final file = File(pathOrUrl);
      if (file.existsSync()) {
        final canonicalPath = file.resolveSymbolicLinksSync();
        return Uri.file(canonicalPath).toString();
      }
    } catch (_) {}

    final uri = Uri.tryParse(pathOrUrl);
    if (uri != null && uri.hasScheme && !(Platform.isWindows && RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(pathOrUrl))) {
      return pathOrUrl;
    }
    return Uri.file(pathOrUrl).toString();
  }

  void _setSubtitleScale(double scale) {
    final clamped = scale.clamp(0.5, 3.0);
    setState(() => _subtitleScale = clamped);
    PlayerSettings.setSubScale(clamped, player: _player);
  }

  Future<void> _applyLiveDelay(double delaySec) async {
    _subtitleDelayMs = delaySec * 1000.0;
    final np = _player.platform as dynamic;
    try {
      np.setProperty('sub-delay', delaySec.toString());
    } catch (e) {
      print('[PlayerScreen] applyLiveDelay error: $e');
    }
  }

  Future<void> _saveTextSyncedCues(List<SubCue> syncedCues, double offsetSec) async {
    _currentCues = syncedCues;
    _subtitleDelayMs = 0.0; // Reset live delay since timestamps are now permanently baked into cues
    if (_currentSubtitlePath != null) {
      final content = _currentSubFormat == SubFormat.vtt
          ? SubtitleParser.toVtt(syncedCues)
          : SubtitleParser.toSrt(syncedCues);
      final ext = _currentSubFormat == SubFormat.vtt ? 'vtt' : 'srt';
      final cleanBase = _currentSubtitlePath!.replaceAll(
        RegExp(r'(_delayed.*|_synced.*)?\.(srt|vtt)$', caseSensitive: false),
        '',
      );
      final newPath =
          '${cleanBase}_synced_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final oldPath = _currentSubtitlePath;
      await File(newPath).writeAsString(content, flush: true);
      _currentSubtitlePath = newPath;
      final resolvedUri = _resolveSubtitleUri(newPath);
      _player.setSubtitleTrack(SubtitleTrack.uri(resolvedUri));
      if (oldPath != null && oldPath != newPath) {
        SubtitleService().deleteSubtitleFile(oldPath);
      }
      _setSubtitleScale(_subtitleScale);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Subtitle timing synchronized and saved!')),
        );
      }
    }
  }

  void _onControllerError(dynamic err) {
    if (!mounted) return;
    final errorMsg = err.toString();
    final lower = errorMsg.toLowerCase();

    // 0. Hardware decoder / shader pipeline error detection & recovery
    if (PlayerSettings.isHardwareDecoderError(err) &&
        !_hasFallenBackToSoftware &&
        PlayerSettings.autoRecoverBlackScreen.value) {
      debugPrint('[PlayerScreen] Hardware decoder error detected in error stream: $errorMsg');
      _triggerSoftwareFallback(reason: 'Hardware decoder error: $errorMsg');
      return;
    }

    // 1. Subtitle track loading errors - non-fatal, notify user briefly without interrupting playback
    if (lower.contains('can not open external file') ||
        lower.contains('subtitle') ||
        lower.contains('sub-add') ||
        lower.contains('.srt') ||
        lower.contains('.vtt') ||
        lower.contains('.ass')) {
      debugPrint('[PlayerScreen] Ignored non-fatal subtitle warning: $errorMsg');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load subtitle: $errorMsg'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // 2. Ignore non-fatal MPV/FFmpeg network and demuxer warnings (e.g. "tcp: ffurl_read returned 0xffffff99")
    if (PlayerSettings.isNonFatalError(err)) {
      debugPrint('[PlayerScreen] Ignored non-fatal player warning: $errorMsg');
      return;
    }

    // 3. Active playback protection:
    // Only routine non-fatal hiccups during ongoing playback (where media has actively loaded and progressed)
    // should be suppressed. Startup errors where media has not loaded must trigger error handling.
    final bool hasActivelyProgressed = _duration > Duration.zero &&
        (_position > Duration.zero || _player.state.position > Duration.zero) &&
        (_isPlaying || _player.state.playing);

    final bool isFatalOpenFailure = lower.contains('failed to open') ||
        lower.contains('cannot open') ||
        lower.contains('could not open') ||
        lower.contains('failed to recognize file format') ||
        lower.contains('unsupported file format') ||
        lower.contains('server returned 4') ||
        lower.contains('server returned 5') ||
        lower.contains('failed to resolve') ||
        lower.contains('no such host');

    if (hasActivelyProgressed && !isFatalOpenFailure) {
      debugPrint('[PlayerScreen WARNING] Ignored player warning during active playback: $errorMsg');
      return;
    }

    // 4. Critical error on dead stream
    CrashBreadcrumbs.error(errorMsg, context: 'PlayerScreen.playback $_currentTitle');
    print('[PlayerScreen ERROR] Critical player error on dead stream: $errorMsg');

    if (_currentEpisode != null && widget.detail?.videos.isNotEmpty == true) {
      setState(() {
        _isLoading = false;
        _showSourcesPanel = true;
        _sourcesEpisode = _currentEpisode;
        _sourcesErrorMessage = 'Playback error: $errorMsg. Please select another source below.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _statusMessage = 'Playback error: $errorMsg';
    });
  }

  void _applyVolume(double vol, {bool showHud = false}) {
    final clamped = ((vol * 100).round() / 100.0).clamp(0.0, PlayerVolumeControl.maxVolume);
    setState(() {
      _volume = clamped;
      _isMuted = clamped == 0;
      if (showHud) _showVolumeHud = true;
    });

    if (showHud) {
      _volumeHudTimer?.cancel();
      _volumeHudTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() => _showVolumeHud = false);
      });
    }

    _player.setVolume(clamped * 100.0);

    _volumeSaveDebounceTimer?.cancel();
    _volumeSaveDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      PlayerSettings.setSavedVolume(clamped);
    });
  }

  void _applyBrightness(double val, {bool showHud = false}) {
    final clamped = ((val * 100).round() / 100.0).clamp(0.0, 1.5);
    setState(() {
      _brightness = clamped;
      if (showHud) _showBrightnessHud = true;
    });

    if (showHud) {
      _brightnessHudTimer?.cancel();
      _brightnessHudTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() => _showBrightnessHud = false);
      });
    }

    try {
      final np = _player.platform as dynamic;
      final mpvBrightness = ((clamped - 1.0) * 100).round().clamp(-100, 100);
      np.setProperty('brightness', mpvBrightness.toString());
    } catch (_) {}
  }

  void _toggleMute({bool showHud = false}) {
    if (_volume > 0 && !_isMuted) {
      _lastVolumeBeforeMute = _volume;
      setState(() {
        _isMuted = true;
        if (showHud) _showVolumeHud = true;
      });
      _player.setVolume(0.0);
    } else {
      final restore = _lastVolumeBeforeMute > 0 ? _lastVolumeBeforeMute : 1.0;
      setState(() {
        _volume = restore;
        _isMuted = false;
        if (showHud) _showVolumeHud = true;
      });
      _player.setVolume(restore * 100.0);
    }

    if (showHud) {
      _volumeHudTimer?.cancel();
      _volumeHudTimer = Timer(const Duration(milliseconds: 1300), () {
        if (mounted) setState(() => _showVolumeHud = false);
      });
    }
  }

  void _togglePlayPause() {
    _player.playOrPause();
    _startHideControlsTimer();
  }

  void _seekRelative(Duration offset) {
    final cur = _player.state.position;
    final dur = _player.state.duration;
    final target = cur + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (dur > Duration.zero && target > dur ? dur : target);
    _player.seek(clamped);
    _startHideControlsTimer();
  }

  /// The [Video] the sources panel scrapes for. Movies have no episode, so a
  /// stand-in is built from the detail - the panel only needs its id/title.
  Video? get _sourcesTarget {
    if (_currentEpisode != null) return _currentEpisode;
    final detail = widget.detail;
    if (detail == null) return null;
    return Video(id: detail.id, title: detail.name);
  }

  void _openSourcesPanel() {
    final target = _sourcesTarget;
    if (target == null) return;
    setState(() {
      _showSourcesPanel = true;
      _sourcesEpisode = target;
      _sourcesErrorMessage = null;
      _showEpisodesPanel = false;
      _activeMenu = null;
      _showControls = true;
    });
  }

  void _toggleEpisodesPanel() {
    setState(() {
      _showEpisodesPanel = !_showEpisodesPanel;
      if (_showEpisodesPanel) {
        _showSourcesPanel = false;
        _activeMenu = null;
        _showSubSyncBar = false;
        _showTextSyncOverlay = false;
        _showControls = true;
      }
    });
  }

  void _onEpisodeChosen(Video episode) {
    setState(() {
      _showEpisodesPanel = false;
      _showSourcesPanel = true;
      _sourcesEpisode = episode;
      _sourcesErrorMessage = null;
      _activeMenu = null;
      _showControls = true;
    });
  }

  void _onBackToEpisodes() {
    setState(() {
      _showSourcesPanel = false;
      _showEpisodesPanel = true;
      _sourcesErrorMessage = null;
    });
  }

  void _playNewSource(StreamSource newSource, Video episode) {
    setState(() {
      _showSourcesPanel = false;
      _showEpisodesPanel = false;
      _sourcesErrorMessage = null;
    });
    _switchStream(newSource, episode);
  }

  void _switchStream(StreamSource newSource, Video newEpisode) async {
    CrashBreadcrumbs.stream('switch', title: newEpisode.title);
    _progressSaveTimer?.cancel();
    _frameWatchdogTimer?.cancel();
    _cancelOpenWatchdog();
    _bufferingStallTimer?.cancel();
    _fallbackNoticeTimer?.cancel();
    _fallbackNoticeText = null;
    _savePlaybackProgress();
    _sendFinalScrobble();

    final prevVariant = _currentSubtitleVariant;
    final wasSubEnabled = _isSubtitleEnabled;
    SubtitleService().deleteSubtitleFile(_currentSubtitlePath);
    _cachedSourcesByEpisode.clear();
    try {
      await _player.stop();
    } catch (_) {}

    setState(() {
      _currentSource = newSource;
      _currentEpisode = newEpisode;
      final showName = widget.detail?.name ?? widget.title;
      _isLoading = true;
      if (newEpisode.season == null && newEpisode.episode == null) {
        // A movie has no episode numbering to build a label from.
        _currentTitle = showName;
        _statusMessage = 'Buffering ${newSource.displayTitle}...';
      } else {
        final epNum = newEpisode.episode ?? 1;
        final sNum = newEpisode.season ?? 1;
        _currentTitle = '$showName - S${sNum}E$epNum ${newEpisode.title}';
        _statusMessage = 'Buffering S$sNum:E$epNum - ${newEpisode.title.isNotEmpty ? newEpisode.title : "Episode $epNum"}...';
      }
      _showEpisodesPanel = false;
      _showSourcesPanel = false;
      _activeMenu = null;
      _showSubSyncBar = false;
      _showTextSyncOverlay = false;
      _showSkipButton = false;
      _activeSkipSegment = null;
      _skipSegments = [];
      _subtitleGroups = [];
      _currentSubtitlePath = null;
      _activeStreamUrl = null;
      _currentCues = [];
      _currentSubtitleVariant = prevVariant;
      _isSubtitleEnabled = wasSubEnabled;
    });

    if (newSource.subtitles != null && newSource.subtitles!.isNotEmpty) {
      _loadSourceSubtitles(newSource.subtitles!);
    }

    // Cleanup previous torrent engine if was P2P
    TorrentStreamService().cleanup();

    _initStream();
  }

  void _fetchSkipSegments() async {
    try {
      final detail = widget.detail;
      final showName = widget.detail?.name ?? widget.title;
      final skipData = await SkipSegmentsService.instance.fetchSkipSegments(
        tmdbId: detail?.tmdbId,
        imdbId: (detail != null && detail.id.startsWith('tt')) ? detail.id : null,
        title: showName,
        year: int.tryParse(detail?.year ?? ''),
        type: detail?.type ?? (_currentEpisode != null ? 'tv' : 'movie'),
        season: _currentEpisode?.season,
        episode: _currentEpisode?.episode,
        durationMs: _player.state.duration.inMilliseconds,
      );

      if (skipData != null && mounted) {
        setState(() {
          _skipSegments = skipData.segments;
        });
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Error loading skip segments: $e');
    }
  }

  void _onPlaybackTick(Duration pos) {
    if (_skipSegments.isEmpty) return;

    final dur = _player.state.duration;

    MediaSkipSegment? matched;
    for (final seg in _skipSegments) {
      if (seg.contains(pos, dur)) {
        matched = seg;
        break;
      }
    }

    if (matched != null) {
      if (!_dismissedSegmentKeys.contains(matched.uniqueKey)) {
        if (_activeSkipSegment?.uniqueKey != matched.uniqueKey) {
          setState(() {
            _activeSkipSegment = matched;
            _showSkipButton = true;
          });
        }
      }
    } else {
      if (_activeSkipSegment != null) {
        setState(() {
          _activeSkipSegment = null;
          _showSkipButton = false;
        });
      }
    }
  }

  void _handleSkipSegment(MediaSkipSegment seg) {
    _dismissedSegmentKeys.add(seg.uniqueKey);
    final target = seg.endMs != null
        ? Duration(milliseconds: seg.endMs!)
        : _player.state.duration;

    _player.seek(target + const Duration(milliseconds: 300));

    setState(() {
      _showSkipButton = false;
      _activeSkipSegment = null;
    });
  }

  void _handleDismissSkipSegment(MediaSkipSegment seg) {
    _dismissedSegmentKeys.add(seg.uniqueKey);
    setState(() {
      _showSkipButton = false;
      _activeSkipSegment = null;
    });
  }

  void _savePlaybackProgress() {
    if (widget.detail == null) return;

    final pos = _player.state.position.inSeconds;
    final dur = _player.state.duration.inSeconds;
    if (dur <= 0) return;

    ContinueWatchingService.saveProgress(
      detail: widget.detail!,
      episode: _currentEpisode,
      source: _currentSource,
      positionSeconds: pos,
      totalDurationSeconds: dur,
    );
  }

  void _updateDiscordRpc({bool? isPaused}) {
    final paused = isPaused ?? !_isPlaying;
    final detail = widget.detail;
    final episode = _currentEpisode;
    final title = detail?.name ?? _currentTitle;
    final poster = widget.backdropUrl ?? detail?.poster ?? detail?.background;

    final type = (detail?.type ?? '').toLowerCase();
    final isAnime = type == 'anime' || (detail == null && _currentTitle.toLowerCase().contains('episode') && episode != null);
    final isSeries = type == 'series' || type == 'tv' || (!isAnime && episode != null);

    if (isAnime) {
      DiscordRpcService.instance.setWatchingAnime(
        title: title,
        season: episode?.season,
        episode: episode?.episode,
        episodeTitle: episode?.title,
        posterUrl: poster,
        position: _position,
        duration: _duration,
        isPaused: paused,
      );
    } else if (isSeries) {
      DiscordRpcService.instance.setWatchingSeries(
        title: title,
        season: episode?.season,
        episode: episode?.episode,
        episodeTitle: episode?.title,
        posterUrl: poster,
        position: _position,
        duration: _duration,
        isPaused: paused,
      );
    } else {
      DiscordRpcService.instance.setWatchingMovie(
        title: title,
        year: detail?.year,
        posterUrl: poster,
        position: _position,
        duration: _duration,
        isPaused: paused,
      );
    }
  }

  void _sendFinalScrobble() {
    try {
      final detail = widget.detail;
      if (detail == null) return;
      final isColl = detail.isCollection;
      final targetId = (_currentEpisode != null && _currentEpisode!.id.startsWith('tt'))
          ? _currentEpisode!.id
          : (detail.id.startsWith('tt') ? detail.id : (detail.tmdbId ?? detail.id));
      if (targetId.isEmpty) return;
      final s = isColl ? null : _currentEpisode?.season;
      final e = isColl ? null : _currentEpisode?.episode;
      final pos = _player.state.position.inSeconds.toDouble();
      final dur = _player.state.duration.inSeconds.toDouble();
      final progress = (dur > 0 ? (pos / dur) * 100.0 : 0.0).clamp(0.0, 100.0);
      TraktService.instance.isAuthenticated().then((authed) {
        if (authed) {
          TraktService.instance.scrobbleStop(targetId, progress, season: s, episode: e);
        }
      });
      SimklService.instance.isAuthenticated().then((authed) {
        if (authed) {
          SimklService.instance.scrobbleStop(targetId, progress, season: s, episode: e);
        }
      });
    } catch (_) {}
  }

  Future<void> _stopPlaybackForPop() async {
    _sendFinalScrobble();
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await TorrentStreamService().cleanup();
    } catch (_) {}
  }

  Future<void> _handleBack() async {
    // Bounded on purpose. _stopPlaybackForPop awaits media_kit's process-wide,
    // non-reentrant lock - the same lock a hung open() holds for its whole body -
    // so an unbounded await here could trap the user on a stalled player with the
    // back button as their only escape. Leaving the screen matters more than a
    // tidy stop, so give it a deadline and pop regardless.
    await _stopPlaybackForPop().timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
    if (!mounted) return;
    if (!_wasFullscreenBeforeEntering &&
        WindowService.instance.isFullscreen) {
      WindowService.instance.exitFullscreen();
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    CrashBreadcrumbs.stream('stop', title: _currentTitle);
    for (final s in _subscriptions) {
      s.cancel();
    }
    _progressSaveTimer?.cancel();
    _frameWatchdogTimer?.cancel();
    _cancelOpenWatchdog();
    _bufferingStallTimer?.cancel();
    _fallbackNoticeTimer?.cancel();
    _volumeHudTimer?.cancel();
    _brightnessHudTimer?.cancel();
    _unlockButtonTimer?.cancel();
    _volumeSaveDebounceTimer?.cancel();
    _audioHudTimer?.cancel();
    _aspectHudTimer?.cancel();
    _savePlaybackProgress();
    _sendFinalScrobble();
    WakelockPlus.disable();
    _hideTimer?.cancel();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    PlayerSettings.changeNotifier.removeListener(_onPlayerSettingsChanged);
    _positionNotifier.dispose();
    _bufferNotifier.dispose();
    // No VideoController.dispose in pinned media_kit_video
    // (video_controller.dart:56-172); Player.dispose owns the texture.
    try {
      _player.stop().catchError((_) {});
    } catch (_) {}
    _player.dispose();
    _logoAnimController.dispose();
    SubtitleService().deleteSubtitleFile(_currentSubtitlePath);
    _cachedSourcesByEpisode.clear();
    TorrentStreamService().cleanup();
    if (!_wasFullscreenBeforeEntering && WindowService.instance.isFullscreen) {
      WindowService.instance.exitFullscreen();
    }
    DiscordRpcService.instance.clearToIdle();
    super.dispose();
  }

  void _onPlayerSettingsChanged() {
    PlayerSettings.applyToPlayer(_player);
  }

  void _lockPlayer() {
    setState(() {
      _isLocked = true;
      _showControls = false;
      _activeMenu = null;
      _showUnlockButton = true;
    });
    HapticFeedback.mediumImpact();
    _startUnlockButtonTimer();
  }

  void _unlockPlayer() {
    _unlockButtonTimer?.cancel();
    setState(() {
      _isLocked = false;
      _showUnlockButton = false;
      _showControls = true;
    });
    HapticFeedback.mediumImpact();
    _startHideControlsTimer();
  }

  void _startUnlockButtonTimer() {
    _unlockButtonTimer?.cancel();
    _unlockButtonTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isLocked) {
        setState(() => _showUnlockButton = false);
      }
    });
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (_isLocked || _isLoading) return;
    if (_activeMenu != null) return;

    _rateBeforeHold = _player.state.rate > 0 ? _player.state.rate : 1.0;
    _wasPausedBeforeHold = !_player.state.playing;
    _isFastForwarding = true;
    _player.setRate(2.0);
    if (_wasPausedBeforeHold) {
      _player.play();
    }
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (!_isFastForwarding) return;
    _isFastForwarding = false;
    _player.setRate(_rateBeforeHold);
    if (_wasPausedBeforeHold) {
      _player.pause();
    }
    HapticFeedback.lightImpact();
    setState(() {});
  }

  void _handleLongPressCancel() {
    if (!_isFastForwarding) return;
    _isFastForwarding = false;
    _player.setRate(_rateBeforeHold);
    if (_wasPausedBeforeHold) {
      _player.pause();
    }
    setState(() {});
  }

  void _handleVerticalDragStart(DragStartDetails details) {
    if (_isLocked || _isLoading) return;
    if (_activeMenu != null) return;

    final screenWidth = MediaQuery.sizeOf(context).width;
    _dragStartY = details.globalPosition.dy;

    if (details.globalPosition.dx < screenWidth / 2) {
      // Left side: Brightness
      _isDraggingBrightness = true;
      _isDraggingVolume = false;
      _dragStartValue = _brightness;
      setState(() => _showBrightnessHud = true);
      _brightnessHudTimer?.cancel();
    } else {
      // Right side: Volume
      _isDraggingBrightness = false;
      _isDraggingVolume = true;
      _dragStartValue = _volume;
      setState(() => _showVolumeHud = true);
      _volumeHudTimer?.cancel();
    }
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isLocked || _isLoading) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final double deltaDy = _dragStartY - details.globalPosition.dy;
    final double sensitivity = 1.3 / (screenHeight * 0.65);
    final double deltaValue = deltaDy * sensitivity;

    if (_isDraggingBrightness) {
      final newBrightness = (_dragStartValue + deltaValue).clamp(0.0, 1.5);
      _applyBrightness(newBrightness, showHud: true);
    } else if (_isDraggingVolume) {
      final newVolume = (_dragStartValue + deltaValue).clamp(0.0, PlayerVolumeControl.maxVolume);
      _applyVolume(newVolume, showHud: true);
    }
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    _isDraggingBrightness = false;
    _isDraggingVolume = false;

    _brightnessHudTimer?.cancel();
    _brightnessHudTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showBrightnessHud = false);
    });

    _volumeHudTimer?.cancel();
    _volumeHudTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showVolumeHud = false);
    });
  }

  void _handleVerticalDragCancel() {
    _isDraggingBrightness = false;
    _isDraggingVolume = false;
    if (mounted) {
      setState(() {
        _showBrightnessHud = false;
        _showVolumeHud = false;
      });
    }
  }

  DateTime? _lastScreenTapTime;

  void _handleScreenTap() {
    if (_isLocked) {
      setState(() {
        _showUnlockButton = !_showUnlockButton;
      });
      if (_showUnlockButton) {
        _startUnlockButtonTimer();
      }
      return;
    }

    final now = DateTime.now();
    if (_lastScreenTapTime != null &&
        now.difference(_lastScreenTapTime!) < const Duration(milliseconds: 280)) {
      _lastScreenTapTime = null;
      WindowService.instance.toggleFullscreen();
    } else {
      _lastScreenTapTime = now;
      _toggleControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          if (!_wasFullscreenBeforeEntering && WindowService.instance.isFullscreen) {
            WindowService.instance.exitFullscreen();
          }
        } else if (_isLocked) {
          setState(() => _showUnlockButton = true);
          _startUnlockButtonTimer();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Screen is locked. Tap the lock icon to unlock.'),
              duration: Duration(seconds: 2),
              backgroundColor: Color(0xFF131722),
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            // Never intercept key events when typing or searching in text inputs or overlay
            if (_showTextSyncOverlay) {
              return KeyEventResult.ignored;
            }
            final primaryFocus = FocusManager.instance.primaryFocus;
            if (primaryFocus != null && primaryFocus.context != null) {
              final focusedWidget = primaryFocus.context!.widget;
              if (focusedWidget is EditableText) {
                return KeyEventResult.ignored;
              }
            }

            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                  event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
                _applyVolume((_volume + 0.05).clamp(0.0, PlayerVolumeControl.maxVolume), showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
                  event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
                _applyVolume((_volume - 0.05).clamp(0.0, PlayerVolumeControl.maxVolume), showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
                _toggleMute(showHud: true);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.keyK) {
                _togglePlayPause();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.keyJ) {
                _seekRelative(const Duration(seconds: -10));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
                  event.logicalKey == LogicalKeyboardKey.keyL) {
                _seekRelative(const Duration(seconds: 10));
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyF ||
                  event.logicalKey == LogicalKeyboardKey.f11) {
                WindowService.instance.toggleFullscreen();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
                _cycleVideoFit();
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                if (WindowService.instance.isFullscreen) {
                  WindowService.instance.exitFullscreen();
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                final delta = pointerSignal.scrollDelta.dy < 0 ? 0.05 : -0.05;
                final next = (_volume + delta).clamp(0.0, PlayerVolumeControl.maxVolume);
                _applyVolume((next * 100).round() / 100.0, showHud: true);
              }
            },
            child: MouseRegion(
              cursor: (_showControls || _isLoading || _activeMenu != null)
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.none,
              onHover: (_) => _handlePointerActivity(),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _handleScreenTap,
                onLongPressStart: _handleLongPressStart,
                onLongPressEnd: _handleLongPressEnd,
                onLongPressCancel: _handleLongPressCancel,
                onVerticalDragStart: _handleVerticalDragStart,
                onVerticalDragUpdate: _handleVerticalDragUpdate,
                onVerticalDragEnd: _handleVerticalDragEnd,
                onVerticalDragCancel: _handleVerticalDragCancel,
                child: _buildPlayerBody(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundStack() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Video Player Surface is ALWAYS mounted in the render tree to guarantee
        // texture / Android surface initialization and eliminate black screen deadlocks.
        SizedBox.expand(
          child: ValueListenableBuilder<int>(
            valueListenable: PlayerSettings.changeNotifier,
            builder: (context, _, __) {
              return mk.Video(
                controller: _videoController,
                fit: _videoFit,
                controls: mk.NoVideoControls,
                subtitleViewConfiguration: PlayerSettings.getSubtitleViewConfiguration(),
              );
            },
          ),
        ),

        // Visual Brightness Overlay:
        // Down to 0 makes the screen completely pitch black.
        // Above 1.0 up to 1.5 boosts highlights and brightness.
        if (_brightness < 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.black.withValues(
                  alpha: (1.0 - _brightness).clamp(0.0, 1.0),
                ),
              ),
            ),
          )
        else if (_brightness > 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: Colors.white.withValues(
                  alpha: ((_brightness - 1.0) * 0.40).clamp(0.0, 0.35),
                ),
              ),
            ),
          ),

        // 2. Loading / Buffering Overlay (rendered over the video during loading)
        if (_isLoading) ...[
          if (widget.backdropUrl != null)
            Positioned.fill(
              child: Opacity(
                opacity: 0.4,
                child: Image.network(
                  widget.backdropUrl!,
                  cacheWidth: 1280,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              color: widget.backdropUrl != null ? Colors.black54 : Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_streamStalled)
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white70,
                        size: 56,
                      )
                    else if (widget.logoUrl != null)
                      AnimatedBuilder(
                        animation: _logoAnimController,
                        builder: (context, child) {
                          final val = _logoAnimController.value;
                          return Opacity(
                            opacity: 0.3 + (val * 0.7),
                            child: Transform.scale(
                              scale: 0.95 + (val * 0.1),
                              child: child,
                            ),
                          );
                        },
                        child: Image.network(
                          widget.logoUrl!,
                          cacheHeight: 300,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      )
                    else
                      CircularProgressIndicator(color: PlayerTheme.accent),
                    const SizedBox(height: 32),
                    Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (_streamStalled) ...[
                      const SizedBox(height: 22),
                      Wrap(
                        spacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _openSourcePicker,
                            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                            label: const Text('Choose another source'),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Text('Go back'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleDownloadMedia() async {
    final mediaId = widget.detail?.id ?? _currentTitle;
    final season = _currentEpisode?.season;
    final episode = _currentEpisode?.episode;

    final existing = DownloadService.instance.tasksNotifier.value.where((t) {
      if (t.mediaId == mediaId && t.season == season && t.episode == episode) {
        return true;
      }
      return false;
    }).firstOrNull;

    if (existing != null) {
      if (existing.status == DownloadStatus.downloading) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download already in progress in background.')),
        );
        return;
      } else if (existing.status == DownloadStatus.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This media is already downloaded.')),
        );
        return;
      }
    }

    try {
      String? customDir;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        customDir = await DownloadPathHelper.pickDownloadsDirectory();
        if (customDir == null) {
          // User canceled folder selection
          return;
        }
      }

      await DownloadService.instance.startDownload(
        title: widget.detail?.name ?? _currentTitle,
        mediaId: mediaId,
        type: widget.detail?.type ?? (widget.detail?.videos.isNotEmpty == true ? 'series' : 'movie'),
        season: season,
        episode: episode,
        episodeTitle: _currentEpisode?.title,
        posterUrl: widget.detail?.poster,
        backdropUrl: widget.detail?.background,
        year: widget.detail?.year,
        source: _currentSource,
        customDownloadDir: customDir,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download started in background. Track progress in Downloads tab.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed to start: $e')),
        );
      }
    }
  }

  void _handleCopyStreamUrl() {
    final url = _activeStreamUrl ?? _currentSource.url;
    if (url != null && url.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.link_rounded, color: Colors.greenAccent, size: 18),
                SizedBox(width: 8),
                Text(
                  'Stream URL copied to clipboard',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E2028),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
            margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active stream URL available to copy.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildControlsOverlay() {
    final buffered = _buffered;

    final isColl = widget.detail?.isCollection == true;
    final episodeTitle = _currentEpisode?.title;
    final episodeSubtitle = _currentEpisode != null
        ? (isColl
            ? 'Part ${_currentEpisode!.episode ?? 1}${episodeTitle != null && episodeTitle.isNotEmpty ? " • $episodeTitle" : ""}'
            : 'S${_currentEpisode!.season ?? 1}:E${_currentEpisode!.episode ?? 1}${episodeTitle != null && episodeTitle.isNotEmpty ? " • $episodeTitle" : ""}')
        : widget.detail?.year;

    final isOfflineFile = _currentSource.name == 'Downloaded';

    return Stack(
      children: [
        // Outside Tap Barrier to dismiss active floating menu
        if (_activeMenu != null)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _activeMenu = null),
              child: Container(color: Colors.transparent),
            ),
          ),

        // Automatic Fallback / Black Screen Recovery Notice HUD
        if (_fallbackNoticeText != null)
          Positioned(
            top: 70,
            left: 24,
            right: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF131722).withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.7), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _fallbackNoticeText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Top Header Bar
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: (!_showControls && !_isLoading) || _showSubSyncBar || _showTextSyncOverlay || _isLocked,
            child: AnimatedOpacity(
              opacity: (_showControls || _isLoading) && !_showSubSyncBar && !_showTextSyncOverlay && !_isLocked
                  ? 1.0
                  : 0.0,
              duration: const Duration(milliseconds: 200),
              child: MouseRegion(
                onEnter: (_) {
                  _isHoveringUI = true;
                  _hideTimer?.cancel();
                },
                onExit: (_) {
                  _isHoveringUI = false;
                  _startHideControlsTimer();
                },
                child: ValueListenableBuilder<List<DownloadTask>>(
                  valueListenable: DownloadService.instance.tasksNotifier,
                  builder: (context, tasks, _) {
                    final mediaId = widget.detail?.id ?? _currentTitle;
                    final season = _currentEpisode?.season;
                    final episode = _currentEpisode?.episode;
                    final isDownloading = tasks.any((t) =>
                        t.mediaId == mediaId &&
                        t.season == season &&
                        t.episode == episode &&
                        t.status == DownloadStatus.downloading);

                    return PlayerTopBar(
                      title: widget.detail?.name ?? _currentTitle,
                      subtitle: episodeSubtitle,
                      quality: _currentSource.name,
                      onDownload: (_isLoading || isOfflineFile) ? null : _handleDownloadMedia,
                      isDownloading: isDownloading,
                      onCopyStreamUrl: _isLoading ? null : _handleCopyStreamUrl,
                      onLock: _isMobile ? _lockPlayer : null,
                      onToggleEpisodes: (!_isLoading && widget.detail?.videos.isNotEmpty == true)
                          ? _toggleEpisodesPanel
                          : null,
                      isEpisodesActive: _showEpisodesPanel,
                      onShowSources: (!_isLoading && _sourcesTarget != null)
                          ? _openSourcesPanel
                          : null,
                      isSourcesActive: _showSourcesPanel,
                      onBack: () {
                        _handleBack();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),

          // Bottom Transport Bar
          if (!_isLoading)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: (!_showControls && _activeMenu == null) || _showTextSyncOverlay || _isLocked,
                child: AnimatedOpacity(
                  opacity: (_showControls || _activeMenu != null) && !_showTextSyncOverlay && !_isLocked ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: MouseRegion(
                    onEnter: (_) {
                      _isHoveringUI = true;
                      _hideTimer?.cancel();
                    },
                    onExit: (_) {
                      _isHoveringUI = false;
                      _startHideControlsTimer();
                    },
                    child: ValueListenableBuilder<bool>(
                      valueListenable: WindowService.instance.isFullscreenNotifier,
                      builder: (context, isFs, _) {
                        return PlayerTransport(
                          isPlaying: _isPlaying,
                          position: _position,
                          duration: _duration,
                          buffered: buffered,
                          positionListenable: _positionNotifier,
                          bufferedListenable: _bufferNotifier,
                          skipSegments: _skipSegments,
                          volume: _volume,
                          isMuted: _isMuted || _volume == 0,
                          playbackRate: _playbackRate,
                          isSubtitlesActive: _isSubtitleEnabled && _currentSubtitleVariant != null,
                          isSubSyncActive: _selectedEmbeddedSubtitleIndex == null && (_showSubSyncBar || _subtitleDelayMs != 0),
                          isAudioActive: _selectedAudioTrackIndex > 0,
                          isEpisodesActive: _showEpisodesPanel || _showSourcesPanel,
                          isFullscreen: isFs,
                          onToggleEpisodes: (widget.detail?.videos.isNotEmpty == true)
                              ? _toggleEpisodesPanel
                              : null,
                          onPlayPause: () {
                            _togglePlayPause();
                          },
                          onSeek: (pos) => _player.seek(pos),
                          onSeekBack10: () {
                            _seekRelative(const Duration(seconds: -10));
                          },
                          onSeekForward10: () {
                            _seekRelative(const Duration(seconds: 10));
                          },
                          onVolumeChanged: (vol) => _applyVolume(vol),
                          onToggleMute: () => _toggleMute(),
                          onToggleAspectMenu: () => _toggleMenu('aspect'),
                          onToggleSpeedMenu: () => _toggleMenu('speed'),
                          onToggleAudioMenu: () => _toggleMenu('audio'),
                          onToggleSubtitleMenu: () => _toggleMenu('subtitle'),
                          onToggleSubSync: () {
                            if (_selectedEmbeddedSubtitleIndex != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Subtitle sync is not supported for embedded subtitles. Please select an external subtitle.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            if (_currentSubtitlePath == null || _currentSubtitleVariant == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please load an external subtitle to use subtitle sync.'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _showSubSyncBar = !_showSubSyncBar;
                              _activeMenu = null;
                            });
                          },
                          onToggleFullscreen: () => WindowService.instance.toggleFullscreen(),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

          // Floating Subtitle Menu Popover
          if (_activeMenu == 'subtitle' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height < 500
                  ? 44
                  : (MediaQuery.sizeOf(context).width < 560
                      ? 60
                      : (MediaQuery.sizeOf(context).width < 680 ? 76 : 96)),
              right: MediaQuery.sizeOf(context).width < 560
                  ? 8
                  : (MediaQuery.sizeOf(context).width < 680 ? 12 : 28),
              left: MediaQuery.sizeOf(context).width < 560 ? 8 : null,
              child: Align(
                alignment: MediaQuery.sizeOf(context).width < 560
                    ? Alignment.bottomCenter
                    : Alignment.bottomRight,
                child: PlayerSubtitleMenu(
                  groups: _subtitleGroups,
                  embeddedSubtitles: _embeddedSubtitles,
                  selectedEmbeddedIndex: _selectedEmbeddedSubtitleIndex,
                  selectedVariant: _currentSubtitleVariant,
                  isSubtitleEnabled: _isSubtitleEnabled,
                  movieTitle: widget.detail?.name ?? widget.title,
                  imdbId: widget.detail?.id,
                  season: _currentEpisode?.season,
                  episode: _currentEpisode?.episode,
                  year: widget.detail?.year != null ? int.tryParse(widget.detail!.year!) : null,
                  delaySec: _subtitleDelayMs / 1000.0,
                  onSelectVariant: (v) {
                    if (v != null) _loadSubtitle(v);
                  },
                  onSelectEmbedded: (emb) => _selectEmbeddedSubtitle(emb),
                  onToggleOff: _disableSubtitles,
                  onOpenSyncBar: () {
                    if (_selectedEmbeddedSubtitleIndex != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Subtitle sync is not supported for embedded subtitles.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _activeMenu = null;
                      _showSubSyncBar = true;
                    });
                  },
                  onOpenStyleBar: () {
                    setState(() => _activeMenu = 'style');
                  },
                  onOpenTextSync: () {
                    if (_selectedEmbeddedSubtitleIndex != null || _currentSubtitlePath == null || _currentCues.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Speech sync requires an external subtitle file.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _activeMenu = null;
                      _showTextSyncOverlay = true;
                    });
                  },
                  onClose: () => setState(() => _activeMenu = null),
                ),
              ),
            ),

          // Floating Audio Menu Popover
          if (_activeMenu == 'audio' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height < 500
                  ? 46
                  : (MediaQuery.sizeOf(context).width < 680 ? 76 : 96),
              right: MediaQuery.sizeOf(context).width < 680 ? 12 : 28,
              child: PlayerAudioMenu(
                audioTracks: _audioTracks,
                selectedIndex: _selectedAudioTrackIndex,
                delaySec: _audioDelaySec,
                onTrackSelected: (idx) {
                  setState(() => _selectedAudioTrackIndex = idx);
                  try {
                    final matching = _player.state.tracks.audio.firstWhere(
                      (t) => t.id == idx.toString(),
                      orElse: () => AudioTrack(idx.toString(), null, null),
                    );
                    _player.setAudioTrack(matching);
                    final np = _player.platform as dynamic;
                    np.setProperty('aid', idx.toString());
                  } catch (_) {}
                  final match = _audioTracks.where((t) => t.index == idx).firstOrNull;
                  _showAudioHudToast(match?.title ?? 'Track $idx');
                },
                onDelayChanged: (sec) {
                  setState(() => _audioDelaySec = sec);
                  try {
                    final np = _player.platform as dynamic;
                    np.setProperty('audio-delay', sec.toString());
                  } catch (_) {}
                  _showAudioHudToast('AUDIO SYNC: ${sec > 0 ? "+" : ""}${sec.toStringAsFixed(2)}s');
                },
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Speed Menu Popover
          if (_activeMenu == 'speed' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height < 500
                  ? 46
                  : (MediaQuery.sizeOf(context).width < 680 ? 76 : 96),
              right: MediaQuery.sizeOf(context).width < 680 ? 12 : 28,
              child: PlayerSpeedMenu(
                currentRate: _playbackRate,
                onRateSelected: (rate) {
                  setState(() => _playbackRate = rate);
                  _player.setRate(rate);
                },
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Aspect Ratio Popover
          if (_activeMenu == 'aspect' && !_isLoading)
            Positioned(
              bottom: MediaQuery.sizeOf(context).height < 500
                  ? 46
                  : (MediaQuery.sizeOf(context).width < 680 ? 76 : 96),
              right: MediaQuery.sizeOf(context).width < 680 ? 12 : 28,
              child: PlayerAspectMenu(
                currentFit: _videoFit,
                subtitleScale: _subtitleScale,
                onFitSelected: (fit) => setState(() => _videoFit = fit),
                onSubtitleScaleChanged: _setSubtitleScale,
                onClose: () => setState(() => _activeMenu = null),
              ),
            ),

          // Floating Subtitle Appearance & Customization Modal
          if (_activeMenu == 'style' && !_isLoading)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _activeMenu = null),
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () {}, // Prevent tap through
                    child: PlayerSubStyleModal(
                      player: _player,
                      onClose: () => setState(() => _activeMenu = null),
                    ),
                  ),
                ),
              ),
            ),

          // Top Floating Live SubSyncBar
          if (_showSubSyncBar && !_isLoading && _selectedEmbeddedSubtitleIndex == null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 16,
              left: 0,
              right: 0,
              child: SubSyncBar(
                delaySec: _subtitleDelayMs / 1000.0,
                isTextSyncAvailable: _selectedEmbeddedSubtitleIndex == null && _currentSubtitlePath != null && _currentCues.isNotEmpty,
                onDelayChanged: (sec) => _applyLiveDelay(sec),
                onEnterTextSync: () {
                  setState(() {
                    _showSubSyncBar = false;
                    _showTextSyncOverlay = true;
                  });
                },
                onClose: () {
                  setState(() => _showSubSyncBar = false);
                  _startHideControlsTimer();
                },
              ),
            ),

          // In-Player Episodes Side Panel
          if (_showEpisodesPanel && widget.detail?.videos.isNotEmpty == true && !_isLoading)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showEpisodesPanel = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: GestureDetector(
                    onTap: () {},
                    child: PlayerEpisodesPanel(
                      videos: widget.detail!.videos,
                      currentEpisode: _currentEpisode,
                      onEpisodeSelected: _onEpisodeChosen,
                      onClose: () => setState(() => _showEpisodesPanel = false),
                    ),
                  ),
                ),
              ),
            ),

          // In-Player Sources Side Panel (Targeted Scraping & Error Recovery)
          if (_showSourcesPanel && _sourcesEpisode != null && !_isLoading)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showSourcesPanel = false),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.45),
                  child: GestureDetector(
                    onTap: () {},
                    child: PlayerSourcesPanel(
                      episode: _sourcesEpisode!,
                      detail: widget.detail,
                      currentAddonName: _currentSource.addonName,
                      errorMessage: _sourcesErrorMessage,
                      cachedSources: _cachedSourcesByEpisode['${_sourcesEpisode!.season ?? 1}:${_sourcesEpisode!.episode ?? 1}'],
                      onSourcesLoaded: (sources) {
                        _cachedSourcesByEpisode['${_sourcesEpisode!.season ?? 1}:${_sourcesEpisode!.episode ?? 1}'] = sources;
                      },
                      onPlaySource: _playNewSource,
                      showBackToEpisodes: widget.detail?.videos.isNotEmpty == true,
                      onBackToEpisodes: (widget.detail?.videos.isNotEmpty == true)
                          ? _onBackToEpisodes
                          : () => setState(() => _showSourcesPanel = false),
                      onClose: () => setState(() => _showSourcesPanel = false),
                    ),
                  ),
                ),
              ),
            ),

          // Right Drawer Text Sync
          if (_showTextSyncOverlay && !_isLoading && _currentCues.isNotEmpty && _selectedEmbeddedSubtitleIndex == null)
            Positioned.fill(
              child: TextSyncOverlay(
                player: _player,
                initialCues: _currentCues,
                baseOffsetSec: _subtitleDelayMs / 1000.0,
                onClose: () {
                  setState(() => _showTextSyncOverlay = false);
                  _startHideControlsTimer();
                },
                onSave: _saveTextSyncedCues,
              ),
            ),

          // Floating Skip Button (Skip Intro, Skip Recap, Skip Credits, Skip Preview)
          if (_showSkipButton && _activeSkipSegment != null && !_isLoading && !_showTextSyncOverlay && !_showEpisodesPanel && !_showSourcesPanel && !_isLocked)
            Positioned(
              bottom: (_showControls || _activeMenu != null)
                  ? (MediaQuery.paddingOf(context).bottom +
                      (MediaQuery.sizeOf(context).width < 680 ? 108 : 128))
                  : (MediaQuery.paddingOf(context).bottom +
                      (MediaQuery.sizeOf(context).width < 680 ? 22 : 36)),
              right: MediaQuery.sizeOf(context).width < 680 ? 16 : 28,
              child: AnimatedOpacity(
                opacity: _showSkipButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: PlayerSkipButton(
                  segment: _activeSkipSegment!,
                  onSkip: () => _handleSkipSegment(_activeSkipSegment!),
                  onDismiss: () => _handleDismissSkipSegment(_activeSkipSegment!),
                ),
              ),
            ),

          // Center Heads-Up Volume Display (HUD)
          if (_showVolumeHud && !_isLocked)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildVolumeHud(),
              ),
            ),

          // Center Heads-Up Brightness Display (HUD)
          if (_showBrightnessHud && !_isLocked)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildBrightnessHud(),
              ),
            ),

          // 2X Fast-Forward Indicator (HUD)
          if (_isFastForwarding && !_isLocked)
            _buildFastForwardHud(),

          // Left Mobile Lock Button
          if (_isMobile && !_isLocked && _showControls && !_isLoading)
            _buildMobileLeftLockButton(),

          // Mobile Unlock Button
          if (_isLocked)
            _buildMobileUnlockButton(),

          // Center Heads-Up Audio Display (HUD)
          if (_showAudioHud && !_isLocked)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildAudioHud(),
              ),
            ),

          // Center Heads-Up Aspect Ratio / Crop Display (HUD)
          if (_showAspectHud && !_isLocked)
            Positioned.fill(
              child: IgnorePointer(
                child: _buildAspectHud(),
              ),
            ),
        ],
      );
  }

  Widget _buildVolumeHud() {
    final effectiveVol = _isMuted ? 0.0 : _volume;
    final isBoosting = !_isMuted && _volume > 1.001;
    final pct = (effectiveVol * 100).round();
    final boostColor = _volume > 1.75
        ? const Color(0xFFFF3D00)
        : (_volume > 1.0 ? const Color(0xFFFF8A00) : Colors.white);

    IconData volIcon;
    if (_isMuted || _volume == 0) {
      volIcon = Icons.volume_off_rounded;
    } else if (_volume > 1.0) {
      volIcon = Icons.volume_up_rounded;
    } else if (_volume < 0.5) {
      volIcon = Icons.volume_down_rounded;
    } else {
      volIcon = Icons.volume_up_rounded;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBoosting
                ? boostColor.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isBoosting ? boostColor.withValues(alpha: 0.28) : Colors.black54,
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  volIcon,
                  color: isBoosting ? boostColor : Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _isMuted ? 'Muted' : '$pct%',
                  style: TextStyle(
                    color: isBoosting ? boostColor : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isBoosting) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: boostColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: boostColor.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: boostColor),
                        const SizedBox(width: 2),
                        Text(
                          _volume > 1.75 ? 'MAX BOOST' : 'BOOST',
                          style: TextStyle(
                            color: boostColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (effectiveVol / PlayerVolumeControl.maxVolume).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isBoosting
                              ? LinearGradient(
                                  colors: [
                                    Colors.white,
                                    const Color(0xFFFF8A00),
                                    if (_volume > 1.75) const Color(0xFFFF3D00),
                                  ],
                                )
                              : null,
                          color: isBoosting ? null : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrightnessHud() {
    final pct = (_brightness * 100).round();
    final isBoosting = _brightness > 1.001;
    final boostColor = _brightness > 1.35
        ? const Color(0xFFFFD600)
        : const Color(0xFF00E5FF);

    IconData bIcon;
    if (_brightness <= 0.05) {
      bIcon = Icons.brightness_2_rounded;
    } else if (_brightness < 0.6) {
      bIcon = Icons.brightness_medium_rounded;
    } else {
      bIcon = Icons.brightness_high_rounded;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isBoosting
                ? boostColor.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isBoosting ? boostColor.withValues(alpha: 0.25) : Colors.black54,
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  bIcon,
                  color: isBoosting ? boostColor : Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  '$pct%',
                  style: TextStyle(
                    color: isBoosting ? boostColor : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (isBoosting) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: boostColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: boostColor.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: boostColor),
                        const SizedBox(width: 2),
                        Text(
                          'BOOST',
                          style: TextStyle(
                            color: boostColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 140,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.15)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_brightness / 1.5).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isBoosting
                              ? LinearGradient(
                                  colors: [
                                    Colors.white,
                                    const Color(0xFF00E5FF),
                                    if (_brightness > 1.35) const Color(0xFFFFD600),
                                  ],
                                )
                              : null,
                          color: isBoosting ? null : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFastForwardHud() {
    return Positioned(
      top: 54,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1117).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.55),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.28),
                blurRadius: 20,
                spreadRadius: 1,
              ),
              const BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fast_forward_rounded, color: Color(0xFF00E5FF), size: 22),
              SizedBox(width: 8),
              Text(
                '2X Speed',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLeftLockButton() {
    return Positioned(
      left: 28,
      top: 0,
      bottom: 0,
      child: Center(
        child: IgnorePointer(
          ignoring: !_showControls || _isLoading,
          child: AnimatedOpacity(
            opacity: _showControls && !_isLoading ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _lockPlayer,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1117).withValues(alpha: 0.80),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileUnlockButton() {
    return Positioned(
      left: 28,
      top: 0,
      bottom: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _showUnlockButton ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          child: IgnorePointer(
            ignoring: !_showUnlockButton,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _unlockPlayer,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F1117).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                      const BoxShadow(
                        color: Colors.black87,
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_open_rounded,
                        color: Color(0xFF00E5FF),
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Unlock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAudioHudToast(String text) {
    _audioHudTimer?.cancel();
    setState(() {
      _audioHudText = text;
      _showAudioHud = true;
    });
    _audioHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showAudioHud = false);
    });
  }

  Widget _buildAudioHud() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF7C5CFF).withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C5CFF).withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.audiotrack_rounded,
              color: Color(0xFF00D2EF),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              _audioHudText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleVideoFit() {
    setState(() {
      if (_videoFit == BoxFit.contain) {
        _videoFit = BoxFit.cover;
        _showAspectHudToast('ASPECT: FILL / CROP (ZOOM)');
      } else if (_videoFit == BoxFit.cover) {
        _videoFit = BoxFit.fill;
        _showAspectHudToast('ASPECT: STRETCH TO FILL');
      } else {
        _videoFit = BoxFit.contain;
        _showAspectHudToast('ASPECT: FIT TO SCREEN');
      }
    });
  }

  void _showAspectHudToast(String text) {
    _aspectHudTimer?.cancel();
    setState(() {
      _aspectHudText = text;
      _showAspectHud = true;
    });
    _aspectHudTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _showAspectHud = false);
    });
  }

  Widget _buildAspectHud() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFB300).withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.aspect_ratio_rounded,
              color: Color(0xFFFFB300),
              size: 24,
            ),
            const SizedBox(width: 10),
            Text(
              _aspectHudText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerBody() {
    return ValueListenableBuilder<bool>(
      valueListenable: GlassSettings.enabled,
      builder: (context, enabled, _) {
        if (enabled) {
          return LiquidGlassView(
            realTimeCapture: _showControls && !_isLoading,
            useSync: true,
            pixelRatio: 0.85,
            refreshRate: LiquidGlassRefreshRate.deviceRefreshRate,
            regionCapture: true,
            backgroundWidget: _buildBackgroundStack(),
            child: _buildControlsOverlay(),
          );
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: _buildBackgroundStack()),
            RepaintBoundary(child: _buildControlsOverlay()),
          ],
        );
      },
    );
  }
}
