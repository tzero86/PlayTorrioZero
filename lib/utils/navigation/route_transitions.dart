import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/diagnostics/perf_monitor.dart';

/// Standard Material-style push transition helper.
Route<T> materialRoute<T>({required WidgetBuilder builder, RouteSettings? settings}) =>
    PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return _TransitionTimer(
          animation: animation,
          routeName: settings?.name ?? 'material',
          child: FadeTransition(
            opacity: animation,
            child: RepaintBoundary(child: child),
          ),
        );
      },
      settings: settings,
    );

/// A premium, liquid-like circular reveal transition.
/// The new screen expands like a drop of liquid from the exact point the user tapped.
///
/// Cost notes: the reveal mask ([ClipPath]) is the signature feel and stays,
/// but the old Opacity+Scale stacking on top of the clip is gone — a single
/// cheap [Transform.scale] swell remains. The page itself sits in a
/// [RepaintBoundary] so the per-frame clip does not repaint page content.
class LiquidRevealRoute extends PageRouteBuilder {
  final Widget page;
  final Offset? tapPosition;

  LiquidRevealRoute({
    required this.page,
    this.tapPosition,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          opaque: true, // During transition it will still show the previous route, but stops rendering it when finished!
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // A highly organic, fluid curve (starts fast, very long smooth tail)
            final curve = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.2, 1.0, 0.2, 1.0),
              reverseCurve: Curves.easeInCirc,
            );

            // Hoisted out of the per-frame builder: screen size cannot change
            // mid-transition, so never re-query MediaQuery per frame.
            final center = tapPosition ??
                Offset(
                  MediaQuery.sizeOf(context).width / 2,
                  MediaQuery.sizeOf(context).height - 50,
                );

            return _TransitionTimer(
              animation: animation,
              routeName: page.runtimeType.toString(),
              child: AnimatedBuilder(
                animation: curve,
                builder: (context, childWidget) {
                  return ClipPath(
                    clipper: _LiquidRevealClipper(
                      fraction: curve.value,
                      center: center,
                    ),
                    // Subtle scale so the new page "swells" into existence
                    // alongside the circular mask. Transform-only: no saveLayer.
                    child: Transform.scale(
                      scale: 0.95 + (0.05 * curve.value),
                      child: RepaintBoundary(child: childWidget),
                    ),
                  );
                },
                child: child,
              ),
            );
          },
        );
}

class _LiquidRevealClipper extends CustomClipper<Path> {
  final double fraction;
  final Offset center;

  _LiquidRevealClipper({
    required this.fraction,
    required this.center,
  });

  @override
  Path getClip(Size size) {
    // Fast paths: avoid the max-radius math + giant oval at the extremes.
    // At fraction >= 1 the reveal covers everything, so a rect is identical
    // and cheaper than an oval spanning the whole screen.
    if (fraction <= 0.0) return Path();
    if (fraction >= 1.0) return Path()..addRect(Offset.zero & size);

    final path = Path();

    // Maximum distance from the tap point to the furthest corner of the screen
    final maxRadius = _calcMaxRadius(size, center);

    // Current radius based on animation fraction
    final radius = maxRadius * fraction;

    path.addOval(Rect.fromCircle(center: center, radius: radius));
    return path;
  }

  double _calcMaxRadius(Size size, Offset center) {
    final w = math.max(center.dx, size.width - center.dx);
    final h = math.max(center.dy, size.height - center.dy);
    return math.sqrt(w * w + h * h);
  }

  @override
  bool shouldReclip(_LiquidRevealClipper oldClipper) {
    // Epsilon guard: sub-pixel float noise between frames must not reclip.
    // The center is fixed per transition, so only meaningful fraction steps
    // (or an actual center change) trigger a re-clip.
    if (oldClipper.center != center) return true;
    return (oldClipper.fraction - fraction).abs() > 0.001;
  }
}

/// A cinematic content-slide transition for the Watch Screen.
///
/// The incoming page's content slides in from the right and fades in.
/// Slide (transform-only) + a single fade: no clip, no scale stacking.
/// The page sits in a [RepaintBoundary] so the slide does not repaint content.
class CinematicSlideRoute extends PageRouteBuilder {
  final Widget page;

  CinematicSlideRoute({
    required this.page,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          opaque: true,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Incoming page: slide from right + fade in
            final inCurve = CurvedAnimation(
              parent: animation,
              curve: const Cubic(0.25, 0.1, 0.25, 1.0),
              reverseCurve: Curves.easeInCubic,
            );

            final slideIn = Tween<Offset>(
              begin: const Offset(0.15, 0),
              end: Offset.zero,
            ).animate(inCurve);

            final fadeIn = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ));

            return _TransitionTimer(
              animation: animation,
              routeName: page.runtimeType.toString(),
              child: SlideTransition(
                position: slideIn,
                child: FadeTransition(
                  opacity: fadeIn,
                  child: RepaintBoundary(child: child),
                ),
              ),
            );
          },
        );
}

/// Times one push (forward → completed) and one pop (reverse → dismissed)
/// per route and reports both to [PerfMonitor].
///
/// Zero render cost: [build] returns [child] untouched; the only work is a
/// single status listener plus a [Stopwatch].
class _TransitionTimer extends StatefulWidget {
  final Animation<double> animation;
  final String routeName;
  final Widget child;

  const _TransitionTimer({
    required this.animation,
    required this.routeName,
    required this.child,
  });

  @override
  State<_TransitionTimer> createState() => _TransitionTimerState();
}

class _TransitionTimerState extends State<_TransitionTimer> {
  late final Stopwatch _sw;

  @override
  void initState() {
    super.initState();
    _sw = Stopwatch()..start();
    widget.animation.addStatusListener(_onStatus);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      final ms = _sw.elapsedMilliseconds;
      _sw.stop();
      try {
        PerfMonitor.recordRoute('push', widget.routeName, durationMs: ms);
      } catch (_) {}
    } else if (status == AnimationStatus.reverse) {
      // Pop begins: restart the clock so the pop duration is measured alone.
      _sw
        ..reset()
        ..start();
    } else if (status == AnimationStatus.dismissed) {
      final ms = _sw.elapsedMilliseconds;
      _sw.stop();
      try {
        PerfMonitor.recordRoute('pop', widget.routeName, durationMs: ms);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
