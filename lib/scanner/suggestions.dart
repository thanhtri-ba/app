enum SuggestKind { scanNow, oldShots, blurry, duplicates, oldChat }

class Suggestion {
  final SuggestKind kind;

  /// Items involved (photos / groups); for [SuggestKind.scanNow] the days since the last scan
  /// (-1 = never scanned).
  final int n;

  /// Rough space that could be freed; used for ordering and shown for duplicates.
  final int bytes;

  /// Only for duplicates: number of groups.
  final int groups;
  const Suggestion(this.kind, this.n, {this.bytes = 0, this.groups = 0});
}

const int oldShotDays = 90;
const int oldChatDays = 60;

int _olderThan(List<DateTime> dates, DateTime now, int days) {
  final limit = now.subtract(Duration(days: days));
  var n = 0;
  for (final d in dates) {
    if (d.isBefore(limit)) n++;
  }
  return n;
}

/// Picks up to [max] cleanup suggestions, highest impact first. Pure function (unit tested).
List<Suggestion> buildSuggestions({
  required DateTime now,
  required DateTime? lastScan,
  required bool scanned,
  required List<DateTime> screenshotDates,
  required List<DateTime> chatDates,
  required int blurryCount,
  required int dupGroups,
  required int dupBytes,
  int max = 3,
}) {
  final out = <Suggestion>[];

  final oldShots = _olderThan(screenshotDates, now, oldShotDays);
  if (oldShots >= 10) out.add(Suggestion(SuggestKind.oldShots, oldShots, bytes: oldShots * 500 * 1024));

  final oldChat = _olderThan(chatDates, now, oldChatDays);
  if (oldChat >= 20) out.add(Suggestion(SuggestKind.oldChat, oldChat, bytes: oldChat * 800 * 1024));

  if (scanned) {
    if (blurryCount >= 3) {
      out.add(Suggestion(SuggestKind.blurry, blurryCount, bytes: blurryCount * 1024 * 1024));
    }
    if (dupGroups >= 1 && dupBytes >= 5 * 1024 * 1024) {
      out.add(Suggestion(SuggestKind.duplicates, dupGroups, bytes: dupBytes, groups: dupGroups));
    }
  }
  out.sort((a, b) => b.bytes.compareTo(a.bytes));

  // A stale (or missing) scan is always worth saying, and comes first.
  final days = lastScan == null ? -1 : now.difference(lastScan).inDays;
  if (lastScan == null || days >= 7) {
    out.insert(0, Suggestion(SuggestKind.scanNow, days));
  }
  return out.take(max).toList();
}
