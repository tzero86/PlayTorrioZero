/// Guards the form-factor bands the whole shell branches on.
///
/// `FormFactorService.resolve` is the only place the app decides whether it is on
/// a phone, a tablet, a desktop or a television, and every chrome decision reads
/// it: rail versus bottom bar, row heights, target sizes, and whether the keyboard
/// map is bound. The bands are half open and the television test runs first, which
/// are the two facts a rewrite of this file is most likely to get subtly wrong, so
/// both boundaries and the precedence are pinned here.
///
/// Deliberately no widget tree: the point of `resolve` is that it is a pure
/// function over two numbers, so these run in milliseconds.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/layout/form_factor.dart';

void main() {
  group('the bands are half open, so a boundary takes the larger form factor', () {
    test('just below the tablet band is a phone', () {
      expect(
        FormFactorService.resolve(shortestSide: 599, remoteInput: false),
        FormFactor.compact,
      );
    });

    test('and exactly on it is a tablet, so a resized window cannot flicker', () {
      expect(
        FormFactorService.resolve(shortestSide: 600, remoteInput: false),
        FormFactor.medium,
      );
    });

    test('just below the desktop band is still a tablet', () {
      expect(
        FormFactorService.resolve(shortestSide: 1023, remoteInput: false),
        FormFactor.medium,
      );
    });

    test('and exactly on it is a desktop', () {
      expect(
        FormFactorService.resolve(shortestSide: 1024, remoteInput: false),
        FormFactor.expanded,
      );
    });
  });

  group('remote input wins over the size bands', () {
    test('a television is a television even at phone width', () {
      // A TV surface can be narrow enough to fall in the compact band and still
      // needs the ten-foot chrome, because what defines it is the D-pad.
      expect(
        FormFactorService.resolve(shortestSide: 480, remoteInput: true),
        FormFactor.television,
      );
    });

    test('and at desktop width too', () {
      expect(
        FormFactorService.resolve(shortestSide: 1920, remoteInput: true),
        FormFactor.television,
      );
    });

    test('without remote input the same sizes are not a television', () {
      expect(
        FormFactorService.resolve(shortestSide: 480, remoteInput: false),
        FormFactor.compact,
      );
      expect(
        FormFactorService.resolve(shortestSide: 1920, remoteInput: false),
        FormFactor.expanded,
      );
    });
  });

  test('the pinned breakpoints are the ones the chrome was measured against', () {
    expect(FormFactorService.mediumMin, 600);
    expect(FormFactorService.expandedMin, 1024);
  });
}
