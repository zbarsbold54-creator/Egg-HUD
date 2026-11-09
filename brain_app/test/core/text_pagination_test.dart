import 'package:flutter_test/flutter_test.dart';
import 'package:brain_app/core/utils/text_pagination.dart';

void main() {
  group('TextPagination', () {
    test('wrap short text', () {
      final lines = TextPagination.wrap('Hello world', 20);
      expect(lines, ['Hello world']);
    });

    test('wrap long text', () {
      final lines = TextPagination.wrap('Hello world this is a test', 10);
      expect(lines.length, greaterThan(1));
      for (final l in lines) {
        expect(l.length, lessThanOrEqualTo(10));
      }
    });

    test('paginate', () {
      final pages = TextPagination.paginate(['a', 'b', 'c', 'd', 'e'], 2);
      expect(pages.length, 3);
      expect(pages[0], ['a', 'b']);
      expect(pages[2], ['e']);
    });

    test('summarize', () {
      expect(TextPagination.summarize('short', 20), 'short');
      expect(TextPagination.summarize('a very long text here', 10).length, 10);
    });
  });
}
