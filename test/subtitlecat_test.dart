@Tags(['network'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/services/subtitles/subtitlecat_service.dart';

void main() {
  HttpOverrides.global = null;

  test('SubtitleCat scraper and search', () async {
    final entries = await SubtitleCatService.instance.searchAndExtract(
      title: 'Inception',
      year: 2010,
    );

    expect(entries.isNotEmpty, true);
    print('Found ${entries.length} SubtitleCat entries for Inception:');

    final directEntries = entries.where((e) => !e.isTranslated).toList();
    final trEntries = entries.where((e) => e.isTranslated).toList();

    print('Direct entries: ${directEntries.length}');
    for (final e in directEntries.take(5)) {
      print('  Direct: [${e.code}] ${e.label} -> ${e.url}');
    }

    print('Translatable entries: ${trEntries.length}');
    for (final e in trEntries.take(5)) {
      print('  Translatable: [${e.code}] ${e.label}');
    }

    expect(directEntries.isNotEmpty, true);
    expect(trEntries.isNotEmpty, true);

    // Test on-the-fly translation
    final trSample = trEntries.first;
    print('\nTesting on-the-fly translation for [${trSample.code}] ${trSample.label}...');
    final srt = await SubtitleCatService.instance.translateSrt(
      origUrl: trSample.origUrl,
      targetLang: trSample.code,
    );

    expect(srt.isNotEmpty, true);
    expect(srt.contains('-->'), true);
    print('Translated SRT length: ${srt.length} chars');
    print('Sample translated lines:\n${srt.split('\n').take(12).join('\n')}');
  });
}
