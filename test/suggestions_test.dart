import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/scanner/suggestions.dart';

void main() {
  final now = DateTime(2026, 6, 1);
  List<DateTime> ago(int days, int n) => List.filled(n, now.subtract(Duration(days: days)));

  List<Suggestion> build({
    DateTime? lastScan,
    bool scanned = true,
    List<DateTime> shots = const [],
    List<DateTime> chat = const [],
    int blurry = 0,
    int groups = 0,
    int dupBytes = 0,
    int max = 3,
  }) =>
      buildSuggestions(
        now: now,
        lastScan: lastScan ?? now,
        scanned: scanned,
        screenshotDates: shots,
        chatDates: chat,
        blurryCount: blurry,
        dupGroups: groups,
        dupBytes: dupBytes,
        max: max,
      );

  test('nothing to suggest on a clean, freshly scanned library', () {
    expect(build(), isEmpty);
  });

  test('never scanned -> scan suggestion first with n = -1', () {
    final direct = buildSuggestions(
      now: now,
      lastScan: null,
      scanned: false,
      screenshotDates: const [],
      chatDates: const [],
      blurryCount: 0,
      dupGroups: 0,
      dupBytes: 0,
    );
    expect(direct.first.kind, SuggestKind.scanNow);
    expect(direct.first.n, -1);
  });

  test('stale scan (7+ days) comes first', () {
    final r = build(lastScan: now.subtract(const Duration(days: 9)), blurry: 10);
    expect(r.first.kind, SuggestKind.scanNow);
    expect(r.first.n, 9);
    expect(r[1].kind, SuggestKind.blurry);
  });

  test('a 6-day-old scan is still fresh', () {
    expect(build(lastScan: now.subtract(const Duration(days: 6))), isEmpty);
  });

  test('old screenshots need at least 10 older than 90 days', () {
    expect(build(shots: ago(100, 9)), isEmpty);
    expect(build(shots: ago(100, 10)).single.kind, SuggestKind.oldShots);
    expect(build(shots: ago(30, 50)), isEmpty);
  });

  test('old chat media needs at least 20 older than 60 days', () {
    expect(build(chat: ago(70, 19)), isEmpty);
    expect(build(chat: ago(70, 20)).single.kind, SuggestKind.oldChat);
  });

  test('duplicates ignored below 5 MB, blurry below 3 photos', () {
    expect(build(groups: 2, dupBytes: 4 * 1024 * 1024), isEmpty);
    expect(build(groups: 2, dupBytes: 6 * 1024 * 1024).single.kind, SuggestKind.duplicates);
    expect(build(blurry: 2), isEmpty);
    expect(build(blurry: 3).single.kind, SuggestKind.blurry);
  });

  test('scan-based suggestions are hidden when the library was not scanned', () {
    expect(build(scanned: false, blurry: 50, groups: 5, dupBytes: 100 * 1024 * 1024), isEmpty);
  });

  test('sorted by impact and capped at max', () {
    final r = build(
      shots: ago(100, 20), // ~10 MB
      chat: ago(70, 40), // ~32 MB
      blurry: 5, // ~5 MB
      groups: 3,
      dupBytes: 200 * 1024 * 1024,
    );
    expect(r.length, 3);
    expect(r.map((e) => e.kind).toList(),
        [SuggestKind.duplicates, SuggestKind.oldChat, SuggestKind.oldShots]);
  });
}
