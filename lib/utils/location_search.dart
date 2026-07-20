String normalizeLocationText(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

String locationQueryFromMessage(String message) {
  final match = RegExp(
    r'\b(?:where\s+is|where\s+can\s+i\s+find|find|locate|navigate(?:\s+me)?\s+to|guide(?:\s+me)?\s+to|directions?\s+to)\s+(.+)$',
    caseSensitive: false,
  ).firstMatch(message.trim());
  return (match?.group(1) ?? message)
      .replaceAll(RegExp(r'[?.!,]+$'), '')
      .trim();
}

int locationMatchRank(String query, Iterable<String> fields) {
  final needle = normalizeLocationText(query);
  if (needle.isEmpty) return 0;
  final values = fields.map(normalizeLocationText).where((v) => v.isNotEmpty);
  if (values.any((v) => v == needle)) return 0;
  if (values.any((v) => v.startsWith(needle))) return 1;
  if (values.any((v) => v.contains(needle))) return 2;
  return 3;
}

int? roomNumber(String value) {
  final matches = RegExp(
    r'(?:[a-z]+\d*-)?(\d+)',
    caseSensitive: false,
  ).allMatches(value).toList();
  return matches.isEmpty ? null : int.tryParse(matches.last.group(1)!);
}
