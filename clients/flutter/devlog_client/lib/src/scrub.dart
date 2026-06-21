// Klient tomonidagi scrub (serverdagi bilan bir xil) — maxfiy ma'lumot
// hatto tarmoqqa CHIQMASDAN OLDIN maskalanadi (defense in depth).

final RegExp _bearer = RegExp(r'([Bb]earer\s+)[A-Za-z0-9._\-]+');
final RegExp _kv = RegExp(
  r'("?(?:password|passwd|pin|otp|code|phone|token|secret|api[_-]?key|access[_-]?key|authorization)"?\s*[:=]\s*"?)[^"\s,}]+',
  caseSensitive: false,
);
final RegExp _conn = RegExp(r'(://[^:/\s]+:)[^@/\s]+(@)');

/// Token/parol/connection-string'larni `***` bilan maskalaydi.
String scrubText(String input) {
  return input
      .replaceAllMapped(_bearer, (m) => '${m.group(1)}***')
      .replaceAllMapped(_kv, (m) => '${m.group(1)}***')
      .replaceAllMapped(_conn, (m) => '${m.group(1)}***${m.group(2)}');
}

/// Telefonni qisman yashiradi: `+998901234567` → `+99890***4567`.
String maskPhone(String p) {
  if (p.length < 8) return p;
  return '${p.substring(0, p.length - 7)}***${p.substring(p.length - 4)}';
}
