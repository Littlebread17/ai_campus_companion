import 'package:ai_campus_companion/utils/location_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts a destination from common navigation requests', () {
    expect(
      locationQueryFromMessage('Where is Finance Office?'),
      'Finance Office',
    );
    expect(locationQueryFromMessage('Navigate me to A2-05'), 'A2-05');
    expect(locationQueryFromMessage('guide me to Library'), 'Library');
  });

  test('location search ignores punctuation and ranks prefixes', () {
    expect(normalizeLocationText('A2-05'), 'a205');
    expect(locationMatchRank('A2', ['A2-05']), 1);
    expect(locationMatchRank('A2', ['Room near A2-08']), 2);
    expect(locationMatchRank('A2', ['B3-05']), 3);
  });

  test('room number uses the final room component', () {
    expect(roomNumber('A2-05'), 5);
    expect(roomNumber('RC3-20'), 20);
  });
}
