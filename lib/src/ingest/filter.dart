/// Smart anti-flood filtr (docs/04). Vaqt-oynali dedupe:
/// - `alwaysSend` (crash/freeze/login/5xx) — har doim yuboriladi.
/// - boshqalar (4xx/error) — oyna ichida birinchisi yuboriladi, qolgani
///   bostiriladi va sanaladi; keyingi oynaning birinchisida "×N" bilan chiqadi.
///
/// Bir-instansli xotira backstop (MVP). Miqyosda Redis/Postgres bilan
/// almashtiriladi.
class LogFilter {
  LogFilter({this.window = const Duration(seconds: 60)});

  final Duration window;
  final Map<String, _Bucket> _buckets = {};

  FilterDecision decide(
    String key, {
    required bool alwaysSend,
    DateTime? now,
  }) {
    final t = now ?? DateTime.now();
    final b = _buckets[key];
    if (b == null || t.isAfter(b.windowEnd)) {
      final prevSuppressed = b?.suppressed ?? 0;
      _buckets[key] = _Bucket(t.add(window));
      return FilterDecision(send: true, suppressedBefore: prevSuppressed);
    }
    if (alwaysSend) return const FilterDecision(send: true);
    b.suppressed++;
    return const FilterDecision(send: false);
  }

  /// Eski bucketlarni tozalash (xotira o'smasin) — vaqti-vaqti chaqiriladi.
  void sweep([DateTime? now]) {
    final t = now ?? DateTime.now();
    _buckets.removeWhere((_, b) => t.isAfter(b.windowEnd.add(window)));
  }
}

class FilterDecision {
  const FilterDecision({required this.send, this.suppressedBefore = 0});
  final bool send;
  final int suppressedBefore;
}

class _Bucket {
  _Bucket(this.windowEnd);
  final DateTime windowEnd;
  int suppressed = 0;
}
