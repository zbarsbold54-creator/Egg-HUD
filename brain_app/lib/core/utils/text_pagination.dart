/// Text wrapping and pagination for 128x64 display.
/// Long assistant answers are wrapped and paginated for the glasses,
/// while the phone shows the full output.
library;

class TextPagination {
  /// Wrap [text] to lines of at most [maxChars] characters.
  static List<String> wrap(String text, int maxChars) {
    if (text.isEmpty) return [];
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    String line = '';
    for (final w in words) {
      final test = line.isEmpty ? w : '$line $w';
      if (test.length > maxChars) {
        if (line.isNotEmpty) lines.add(line);
        // Break long words
        if (w.length > maxChars) {
          for (int i = 0; i < w.length; i += maxChars) {
            lines.add(w.substring(i, (i + maxChars).clamp(0, w.length)));
          }
          line = '';
        } else {
          line = w;
        }
      } else {
        line = test;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  /// Paginate wrapped lines into pages of [linesPerPage] lines.
  static List<List<String>> paginate(List<String> lines, int linesPerPage) {
    if (lines.isEmpty) return [[]];
    final pages = <List<String>>[];
    for (int i = 0; i < lines.length; i += linesPerPage) {
      pages.add(lines.sublist(i, (i + linesPerPage).clamp(0, lines.length)));
    }
    return pages;
  }

  /// Summarize long text for glasses display (first N chars + ellipsis).
  static String summarize(String text, int maxChars) {
    if (text.length <= maxChars) return text;
    return '${text.substring(0, maxChars - 3)}...';
  }
}
