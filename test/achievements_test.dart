import 'package:flutter_test/flutter_test.dart';
import 'package:photo_cleaner/core/achievements.dart';
import 'package:photo_cleaner/core/format.dart';

Set<String> days(DateTime base, List<int> offsets) =>
    {for (final o in offsets) dayKey(DateTime(base.year, base.month, base.day - o))};

void main() {
  final now = DateTime(2026, 3, 15, 10);

  group('currentStreak', () {
    test('empty', () => expect(currentStreak({}, now), 0));
    test('only today', () => expect(currentStreak(days(now, [0]), now), 1));
    test('today + 2 previous days', () => expect(currentStreak(days(now, [0, 1, 2]), now), 3));
    test('alive when only yesterday is done', () {
      expect(currentStreak(days(now, [1, 2]), now), 2);
    });
    test('broken after a full missed day', () {
      expect(currentStreak(days(now, [2, 3]), now), 0);
    });
    test('gap ends the run', () => expect(currentStreak(days(now, [0, 1, 3, 4]), now), 2));
    test('crosses a month boundary', () {
      final first = DateTime(2026, 3, 2);
      expect(currentStreak(days(first, [0, 1, 2, 3]), first), 4); // Mar 2, Mar 1, Feb 28, Feb 27
    });
  });

  group('longestStreak', () {
    test('empty', () => expect(longestStreak({}), 0));
    test('single', () => expect(longestStreak(days(now, [5])), 1));
    test('picks the longest run', () {
      expect(longestStreak(days(now, [0, 1, 5, 6, 7, 8, 12])), 4);
    });
  });

  group('badges', () {
    BadgeDef b(String id) => kBadges.firstWhere((x) => x.id == id);
    AchStats s({int bytes = 0, int count = 0, int longest = 0, int tools = 0, int vault = 0}) =>
        AchStats(bytes: bytes, count: count, streak: longest, longest: longest, toolsUsed: tools, vaultItems: vault);

    test('ids are unique', () {
      expect(kBadges.map((x) => x.id).toSet().length, kBadges.length);
    });
    test('thresholds', () {
      expect(b('first').test(s()), false);
      expect(b('first').test(s(count: 1)), true);
      expect(b('mb100').test(s(bytes: 100 * 1024 * 1024 - 1)), false);
      expect(b('mb100').test(s(bytes: 100 * 1024 * 1024)), true);
      expect(b('gb1').test(s(bytes: 1024 * 1024 * 1024)), true);
      expect(b('streak7').test(s(longest: 6)), false);
      expect(b('streak7').test(s(longest: 7)), true);
      expect(b('tools4').test(s(tools: 3)), false);
      expect(b('tools4').test(s(tools: 4)), true);
      expect(b('vault').test(s(vault: 1)), true);
    });
  });
}
