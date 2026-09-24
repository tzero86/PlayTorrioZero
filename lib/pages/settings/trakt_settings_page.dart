import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/trakt/trakt_service.dart';
import '../../services/my_list/my_list_service.dart';
import '../../services/continue_watching/continue_watching_service.dart';
import '../../services/theme/app_theme_service.dart';

class TraktSettingsPage extends StatefulWidget {
  const TraktSettingsPage({super.key});

  @override
  State<TraktSettingsPage> createState() => _TraktSettingsPageState();
}

class _TraktSettingsPageState extends State<TraktSettingsPage> {
  bool _isAuthed = false;
  bool _isLoading = true;
  String? _username;

  // Device Code Pairing
  bool _pairing = false;
  String? _userCode;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() => _isLoading = true);
    final authed = await TraktService.instance.isAuthenticated();
    String? user;
    if (authed) {
      user = await TraktService.instance.getUsername();
    }
    if (mounted) {
      setState(() {
        _isAuthed = authed;
        _username = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _startPairing() async {
    setState(() {
      _pairing = true;
      _userCode = null;
    });

    final res = await TraktService.instance.requestDeviceCode();
    if (!mounted) return;
    if (res == null) {
      setState(() => _pairing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to request Trakt pairing code.')),
      );
      return;
    }

    final userCode = res['user_code'] as String? ?? '';
    final deviceCode = res['device_code'] as String? ?? '';
    final verifyUrl = res['verification_url'] as String? ?? 'https://trakt.tv/activate';
    final interval = (res['interval'] as int? ?? 5).clamp(2, 30);

    setState(() {
      _userCode = userCode;
    });

    // Auto-launch URL
    _openBrowser(verifyUrl);

    // Start Polling
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(Duration(seconds: interval), (t) async {
      final status = await TraktService.instance.pollDeviceToken(deviceCode);
      if (status == null) {
        // Success!
        t.cancel();
        if (mounted) {
          setState(() {
            _pairing = false;
            _isAuthed = true;
          });
          _checkStatus();
          MyListService.syncAll();
          ContinueWatchingService.syncCloudSessions();
        }
      } else if (status == 'expired_token' || status == 'access_denied') {
        t.cancel();
        if (mounted) {
          setState(() => _pairing = false);
        }
      }
    });
  }

  Future<void> _openBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (e) {
        debugPrint('[Trakt] Browser launch error: $e');
      }
    }
  }

  Future<void> _logout() async {
    _pollTimer?.cancel();
    await TraktService.instance.logout();
    await _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
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
          'Trakt.tv Synchronization',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  'Connect your Trakt.tv account to seamlessly synchronize your watch history, watchlist, continue watching progress, and ratings across all your devices.',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.white.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ),

              // Status Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF12151E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAuthed
                        ? const Color(0xFFED1C24).withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 460;

                    final infoWidget = Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFED1C24).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.movie_filter_rounded, color: Color(0xFFED1C24), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Trakt.tv',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (_isAuthed ? const Color(0xFF10B981) : Colors.white24).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _isAuthed ? 'CONNECTED' : 'DISCONNECTED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: _isAuthed ? const Color(0xFF10B981) : Colors.white54,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                                Text(
                                  _isLoading
                                      ? 'Checking credentials...'
                                      : _isAuthed
                                          ? 'Logged in as ${_username ?? 'Trakt User'}'
                                          : 'Sign in to activate two-way cloud sync',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      Widget? actionWidget;
                      if (_isAuthed) {
                        actionWidget = OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          onPressed: _logout,
                          child: const Text('Disconnect', style: TextStyle(fontWeight: FontWeight.bold)),
                        );
                      } else if (!_pairing) {
                        actionWidget = ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFED1C24),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: _startPairing,
                          icon: const Icon(Icons.qr_code_rounded, size: 18),
                          label: const Text('Pair Account', style: TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isNarrow) ...[
                            infoWidget,
                            if (actionWidget != null) ...[
                              const SizedBox(height: 14),
                              SizedBox(width: double.infinity, child: actionWidget),
                            ],
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: infoWidget),
                                if (actionWidget != null) ...[
                                  const SizedBox(width: 14),
                                  actionWidget,
                                ],
                              ],
                            ),
                          ],
                          if (_pairing && _userCode != null) ...[
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white10),
                            const SizedBox(height: 16),
                            Center(
                              child: Column(
                                children: [
                                  const Text(
                                    'Enter this activation code at trakt.tv/activate:',
                                    style: TextStyle(fontSize: 13, color: Colors.white70),
                                  ),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: _userCode!));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Code copied to clipboard!')),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.black45,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFED1C24).withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _userCode!,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 4,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.copy_rounded, color: Colors.white70, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    onPressed: () => _openBrowser('https://trakt.tv/activate'),
                                    icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                                    label: const Text('Open trakt.tv/activate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFED1C24)),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Waiting for authorization on trakt.tv...',
                                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),

              const SizedBox(height: 24),

              // Cloud Sync Actions
              if (_isAuthed) ...[
                const Text(
                  'Cloud Sync Controls',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: const Color(0xFF12151E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  leading: Icon(Icons.sync_rounded, color: AppThemeService.currentPalette.value.primaryColor),
                  title: const Text('Sync Watchlist & Continue Watching Now', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Manually triggers an immediate pull from Trakt', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white38),
                  onTap: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Syncing with Trakt.tv...')),
                    );
                    await Future.wait([
                      MyListService.syncAll(),
                      ContinueWatchingService.syncCloudSessions(),
                    ]);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Trakt sync complete!')),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
