/// A server revision that survives JavaScript DateTime serialization exactly.
DateTime beakRevisionTimestamp(DateTime now, {DateTime? previous}) {
  final millis = now.millisecondsSinceEpoch;
  final preceding = previous?.millisecondsSinceEpoch;
  return DateTime.fromMillisecondsSinceEpoch(
    preceding != null && millis <= preceding ? preceding + 1 : millis,
    isUtc: true,
  );
}

/// Accepts exact revisions and a browser's millisecond view of a legacy value.
/// The eventual conditional write must still compare the exact stored value.
bool beakRevisionMatches(DateTime expected, DateTime stored) =>
    expected.isAtSameMomentAs(stored) ||
    (expected.microsecond == 0 &&
        expected.millisecondsSinceEpoch == stored.millisecondsSinceEpoch);
