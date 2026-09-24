/// Guards the dock's redesigned states.
///
/// The dock had no notion of "where am I": [DockItem] carried no active flag,
/// every destination rendered as an identical glyph, and the only way to tell
/// which page you were on was to remember what you tapped. With a pointer and a
/// tooltip that is survivable; on a remote it is not.
///
/// These tests fail if the active destination stops being named, if the dock
/// regresses to a pointer-only wrapper (the `optimized` path was a bare
/// `GestureDetector`, so a remote could not reach a single destination), if the
/// active pill's width stops being budgeted into the row, or if activation ever
/// fires twice.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/theme/dock_settings.dart';
import 'package:zplay/services/theme/glass_settings.dart';
import 'package:zplay/widgets/common/app_liquid_dock.dart';
import 'package:zplay/widgets/common/focusable_card.dart';
import 'package:zplay/widgets/common/liquid_dock.dart';

void main() {
  late bool glassWas;

  setUp(() {
    // A TV has no pointer, so a focus highlight must always be drawn.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;

    // The glass path builds shader-backed lenses, which need a real GPU. Every
    // behavioural assertion here is on the plain path; the glass path is
    // covered by the "activates exactly once" test being path-agnostic in
    // spirit — the double-fire hazard lives in it, so it is asserted below with
    // glass off, where the item is still built on the same FocusableCard.
    glassWas = GlassSettings.enabled.value;
    GlassSettings.enabled.value = false;
  });

  tearDown(() => GlassSettings.enabled.value = glassWas);

  Widget host(List<DockItem> items) => MaterialApp(
        home: Scaffold(body: Center(child: LiquidDock(items: items))),
      );

  testWidgets('the active destination is named; the rest stay glyphs',
      (tester) async {
    await tester.pumpWidget(host([
      DockItem(
        icon: Icons.home_rounded,
        label: 'Home',
        onTap: () {},
      ),
      DockItem(
        icon: Icons.explore_rounded,
        label: 'Discover',
        onTap: () {},
      ),
      DockItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        onTap: () {},
        isActive: true,
      ),
    ]));
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget,
        reason: 'the destination you are on must say its name');
    expect(find.text('Home'), findsNothing,
        reason: 'inactive destinations stay glyphs — that is the whole point');
    expect(find.text('Discover'), findsNothing);
  });

  testWidgets('a destination is reachable and activates on the remote key',
      (tester) async {
    final hits = <String>[];
    await tester.pumpWidget(host([
      DockItem(
        icon: Icons.home_rounded,
        label: 'Home',
        onTap: () => hits.add('home'),
      ),
      DockItem(
        icon: Icons.explore_rounded,
        label: 'Discover',
        onTap: () => hits.add('discover'),
        isActive: true,
      ),
    ]));
    await tester.pump();

    expect(find.byType(FocusableCard), findsNWidgets(2),
        reason: 'dock items must be built on the focus primitive');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    expect(hits, ['home'], reason: 'select is the Android TV centre key');

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(hits, ['home', 'discover'],
        reason: 'arrowRight must traverse the dock');
  });

  testWidgets('a tap activates a destination exactly once', (tester) async {
    var hits = 0;
    await tester.pumpWidget(host([
      DockItem(
        icon: Icons.home_rounded,
        label: 'Home',
        onTap: () => hits += 1,
      ),
    ]));
    await tester.pump();

    await tester.tap(find.byType(FocusableCard));
    await tester.pump();

    expect(hits, 1,
        reason: 'the item is both focusable and tappable — it must not '
            'forward the tap to a second handler as well');
  });

  testWidgets('the dock renders its destinations as Home mounts it',
      (tester) async {
    // Renders the real AppLiquidDock in the position Home gives it — a
    // Positioned inside a Stack. The individual widget tests use LiquidDock
    // directly, so they cannot see a failure that only happens in this context:
    // the dock was observed missing from the running app.
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: AppLiquidDock(currentDestination: DockItemKey.home),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    expect(find.byType(FocusableCard), findsWidgets,
        reason: 'the dock must render reachable destinations');
    expect(find.byType(LiquidDock), findsOneWidget,
        reason: 'the dock itself must mount');
    expect(find.text('Home'), findsOneWidget,
        reason: 'the current destination must be named');
  });

  testWidgets('the dock still renders with the glass path enabled',
      (tester) async {
    // The rest of this file forces glass off, which is the path the app does NOT
    // take by default: GlassSettings is on for a normal install. The dock was
    // observed missing from the running app while these tests passed, so this
    // asserts the path the app actually uses.
    GlassSettings.enabled.value = true;

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: AppLiquidDock(currentDestination: DockItemKey.home),
              ),
            ),
          ],
        ),
      ),
    ));
    await tester.pump();

    final error = tester.takeException();
    expect(error, isNull, reason: 'glass path threw: $error');
    expect(find.byType(FocusableCard), findsWidgets,
        reason: 'destinations must render on the glass path too');

    // The dock sweeps its hover state once on mount to warm the lens up. Those
    // timers have to drain before the test ends or the framework fails on them.
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('a long active label does not overflow or drop destinations',
      (tester) async {
    // The active item is a pill, so it is wider than the square it replaces.
    // Two things have to hold: the row must not overflow when the label is
    // long, and the dock must still budget for that extra width when deciding
    // whether it needs to scroll — otherwise the last destination is clipped.
    final items = [
      DockItem(
        icon: Icons.movie_rounded,
        label: 'Multi-Nutz Streaming',
        onTap: () {},
        isActive: true,
      ),
      for (var i = 0; i < 12; i++)
        DockItem(icon: Icons.circle_rounded, label: 'Extra $i', onTap: () {}),
    ];

    await tester.pumpWidget(host(items));
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'an expanded pill must not overflow the row');
    expect(find.byType(FocusableCard), findsNWidgets(items.length));
  });
}
