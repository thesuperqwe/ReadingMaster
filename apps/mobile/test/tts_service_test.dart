import 'package:flutter_test/flutter_test.dart';
import 'package:readingmaster/services/tts_service.dart';

void main() {
  group('normalizeForTts', () {
    test('collapses newlines and whitespace runs into single spaces', () {
      expect(
        normalizeForTts('It was a\npicture of a boa constrictor.\r\n\r\nAnd\tthen'),
        'It was a picture of a boa constrictor. And then',
      );
    });

    test('trims surrounding whitespace', () {
      expect(normalizeForTts('  hello   world  '), 'hello world');
    });
  });
}