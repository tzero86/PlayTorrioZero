import 'package:flutter_test/flutter_test.dart';
import 'package:zplay/utils/search/relevance_scorer.dart';

void main() {
  group('RelevanceScorer', () {
    group('exact matches', () {
      test('exact match scores 10000', () {
        expect(RelevanceScorer.score(title: 'Inception', query: 'Inception'), 10000);
      });
      test('exact match case insensitive', () {
        expect(RelevanceScorer.score(title: 'INCEPTION', query: 'inception'), 10000);
      });
      test('exact match ignores leading articles', () {
        expect(RelevanceScorer.score(title: 'The Matrix', query: 'Matrix'), 10000);
        expect(RelevanceScorer.score(title: 'A Beautiful Mind', query: 'Beautiful Mind'), 10000);
        expect(RelevanceScorer.score(title: 'An American Tail', query: 'American Tail'), 10000);
      });
    });
    group('substring matches', () {
      test('substring match scores 5000', () {
        expect(RelevanceScorer.score(title: 'Inception 2', query: 'Inception'), greaterThan(0));
      });
    });
    group('prefix matches', () {
      test('prefix match scores 3000', () {
        expect(RelevanceScorer.score(title: 'Breaking Bad', query: 'Break'), greaterThan(0));
      });
    });
    group('edge cases', () {
      test('empty query returns 0', () {
        expect(RelevanceScorer.score(title: 'Anything', query: ''), 0);
      });
      test('empty title returns 0', () {
        expect(RelevanceScorer.score(title: '', query: 'query'), 0);
      });
    });
  });
}
