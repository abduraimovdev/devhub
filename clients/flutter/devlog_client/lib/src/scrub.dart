final RegExp _bearer = RegExp(r'([Bb]earer\s+)[A-Za-z0-9._\-]+');
final RegExp _kv = RegExp(
  r'("?(?:password|passwd|pin|otp|code|phone|token|secret|api[_-]?key|access[_-]?key|authorization)"?\s*[:=]\s*"?)[^"\s,}]+',
  caseSensitive: false,
);
final RegExp _conn = RegExp(r'(://[^:/\s]+:)[^@/\s]+(@)');

String scrubText(String input) {
  return input
      .replaceAllMapped(_bearer, (m) => '${m.group(1)}***')
      .replaceAllMapped(_kv, (m) => '${m.group(1)}***')
      .replaceAllMapped(_conn, (m) => '${m.group(1)}***${m.group(2)}');
}

String maskPhone(String p) {
  if (p.length < 8) return p;
  return '${p.substring(0, p.length - 7)}***${p.substring(p.length - 4)}';
}
