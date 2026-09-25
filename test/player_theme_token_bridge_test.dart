import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/theme/app_theme_service.dart';
import 'package:zplay/services/theme/design_tokens.dart';
import 'package:zplay/services/theme/glass_settings.dart';
import 'package:zplay/widgets/player/player_glass.dart';
import 'package:zplay/widgets/player/player_speed_menu.dart';
import 'package:zplay/widgets/player/sub_sync_bar.dart';

/// Pins the `PlayerTheme` → contract-token bridge in
/// `lib/widgets/player/player_glass.dart`.
///
/// The player family reads its colours by name off `PlayerTheme`; those members
/// are token-backed getters memoised per palette value. A stale cache would leave
/// the whole player on the previous palette's accent — the exact bug the bridge
/// exists to prevent — so the palette switch is asserted here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final firstPalette = AppThemeService.palettes.first;
  final secondPalette = AppThemeService.palettes[1];
  late AppThemePalette original;
  late bool glassWasEnabled;

  setUp(() {
    original = AppThemeService.currentPalette.value;
    glassWasEnabled = GlassSettings.enabled.value;
    GlassSettings.enabled.value = false; // plain path: no glass lens in tests
  });

  tearDown(() {
    AppThemeService.currentPalette.value = original;
    GlassSettings.enabled.value = glassWasEnabled;
  });

  test('PlayerTheme members resolve through the contract tokens', () {
    AppThemeService.currentPalette.value = firstPalette;
    final tokens = AppThemeService.tokensFor(firstPalette);

    expect(PlayerTheme.accent, tokens.accent);
    expect(PlayerTheme.success, tokens.success);
    expect(PlayerTheme.warning, tokens.warning);
    expect(PlayerTheme.danger, tokens.danger);
    expect(PlayerTheme.ink, tokens.textPrimary);
    expect(PlayerTheme.inkMuted, tokens.textEmphasis);
    expect(PlayerTheme.inkSubtle, tokens.textMuted);
    expect(PlayerTheme.inkDisabled, tokens.textDisabled);
    expect(PlayerTheme.edge, tokens.borderStrong);
    expect(PlayerTheme.edgeSoft, tokens.borderDefault);
    expect(PlayerTheme.raised, tokens.textPrimary.withValues(alpha: ZplayOpacity.borderMedium));
    expect(PlayerTheme.surfaceHover, tokens.textPrimary.withValues(alpha: ZplayOpacity.overlayHover));
    expect(PlayerTheme.canvas, tokens.bg);
  });

  test('PlayerTheme re-resolves when the palette changes', () {
    AppThemeService.currentPalette.value = firstPalette;
    expect(PlayerTheme.accent, firstPalette.primaryColor);

    AppThemeService.currentPalette.value = secondPalette;
    expect(PlayerTheme.accent, secondPalette.primaryColor);
    expect(PlayerTheme.canvas, AppThemeService.tokensFor(secondPalette).bg);
  });

  testWidgets('player chrome renders from the themed tokens', (tester) async {
    AppThemeService.currentPalette.value = firstPalette;
    var tapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeService.createThemeData(firstPalette),
        home: Scaffold(
          backgroundColor: contextlessBg(firstPalette),
          body: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlayerGlassCard(
                  padding: const EdgeInsets.all(ZplaySpacing.s16),
                  child: PlayerIconButton(
                    icon: const Icon(Icons.play_arrow_rounded),
                    tooltip: 'Play',
                    active: true,
                    showActiveBadge: true,
                    onPressed: () => tapped++,
                  ),
                ),
                const SizedBox(height: ZplaySpacing.s8),
                PlayerToggleChip(
                  active: true,
                  label: 'Sources',
                  count: '4',
                  onClick: () => tapped++,
                ),
                const SizedBox(height: ZplaySpacing.s8),
                SubSyncBar(
                  delaySec: 0.25,
                  onDelayChanged: (_) {},
                  onClose: () {},
                ),
                const SizedBox(height: ZplaySpacing.s8),
                PlayerSpeedMenu(
                  currentRate: 1.0,
                  onRateSelected: (_) {},
                  onClose: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(find.text('Sources'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(tapped, 1);
  });
}

Color contextlessBg(AppThemePalette palette) =>
    AppThemeService.tokensFor(palette).bg;
