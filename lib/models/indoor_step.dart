/// One step of indoor walking guidance, optionally tagged with the campus
/// location a student should be at when this step is active. The tag lets the
/// live positioning service auto-tick steps as the student walks.
class IndoorStep {
  final String text;
  final String? expectedBlock;
  final String? expectedLevel;
  final String? expectedPlace;

  const IndoorStep(
    this.text, {
    this.expectedBlock,
    this.expectedLevel,
    this.expectedPlace,
  });

  bool get hasTag => expectedBlock != null || expectedPlace != null;

  /// Does a live position (block/level/place) satisfy this step's tag?
  bool matchedBy({
    required String block,
    required String level,
    required String place,
  }) {
    if (expectedPlace != null &&
        expectedPlace!.isNotEmpty &&
        place.toLowerCase() == expectedPlace!.toLowerCase()) {
      return true;
    }
    if (expectedBlock != null && expectedBlock!.isNotEmpty) {
      if (block.toLowerCase() != expectedBlock!.toLowerCase()) return false;
      // If a level is specified and cleanly comparable, require it too.
      if (expectedLevel != null && expectedLevel!.isNotEmpty) {
        return level.toLowerCase() == expectedLevel!.toLowerCase();
      }
      return true;
    }
    return false;
  }
}
