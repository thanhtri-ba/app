/// Pure helpers for the video compression screen (kept free of Flutter / plugins for testing).
enum VideoSort { size, duration, date }

/// Filters by minimum size and sorts descending by the chosen key.
List<T> viewVideos<T>(
  List<T> items, {
  required int Function(T) bytes,
  required int Function(T) seconds,
  required DateTime Function(T) date,
  required int minBytes,
  required VideoSort sort,
}) {
  final out = items.where((e) => bytes(e) >= minBytes).toList();
  int Function(T, T) cmp;
  switch (sort) {
    case VideoSort.size:
      cmp = (a, b) => bytes(b).compareTo(bytes(a));
    case VideoSort.duration:
      cmp = (a, b) => seconds(b).compareTo(seconds(a));
    case VideoSort.date:
      cmp = (a, b) => date(b).compareTo(date(a));
  }
  out.sort(cmp);
  return out;
}

/// A compressed copy is only worth keeping when it is at least 10% smaller.
bool worthKeeping(int oldBytes, int newBytes) =>
    oldBytes > 0 && newBytes > 0 && newBytes < oldBytes * 0.9;
