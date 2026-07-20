/// Resolves a human-friendly category for an event. Uses the stored `category`
/// field when present, otherwise guesses a descriptive label from the title.
class EventCategory {
  static const options = <String>[
    'Workshop',
    'Talk / Seminar',
    'Sports',
    'Social',
    'Career',
    'Competition',
    'General',
  ];

  /// The descriptive category label for an event document.
  static String resolve(Map<String, dynamic> data) {
    final stored = (data['category'] ?? '').toString().trim();
    if (stored.isNotEmpty) return stored;
    return _derive((data['title'] ?? '').toString());
  }

  static String _derive(String title) {
    final t = title.toLowerCase();
    if (t.contains('workshop') || t.contains('bootcamp') || t.contains('hands-on')) {
      return 'Hands-on Workshop';
    }
    if (t.contains('talk') ||
        t.contains('seminar') ||
        t.contains('webinar') ||
        t.contains('guest')) {
      return 'Talk / Seminar';
    }
    if (t.contains('sport') ||
        t.contains('games') ||
        t.contains('tournament') ||
        t.contains('run') ||
        t.contains('match')) {
      return 'Sports & Games';
    }
    if (t.contains('career') ||
        t.contains('job') ||
        t.contains('fair') ||
        t.contains('recruit') ||
        t.contains('internship')) {
      return 'Career & Recruitment';
    }
    if (t.contains('competition') ||
        t.contains('hackathon') ||
        t.contains('contest') ||
        t.contains('challenge')) {
      return 'Competition';
    }
    if (t.contains('orientation') ||
        t.contains('fresher') ||
        t.contains('welcome') ||
        t.contains('night') ||
        t.contains('party') ||
        t.contains('social')) {
      return 'Social & Community';
    }
    return 'Campus Event';
  }
}
