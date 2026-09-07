final RegExp _bearer = RegExp(r'([Bb]earer\s+)[A-Za-z0-9._\-]+');
final RegExp _tokenKv = RegExp(
  r'("?(?:token|secret|api[_-]?key|access[_-]?key|authorization)"?\s*[:=]\s*"?)[^"\s,}]+',
  caseSensitive: false,
);
final RegExp _conn = RegExp(r'(://[^:/\s]+:)[^@/\s]+(@)');

String scrubText(String input) {
  return input
      .replaceAllMapped(_bearer, (m) => '${m.group(1)}***')
      .replaceAllMapped(_tokenKv, (m) => '${m.group(1)}***')
      .replaceAllMapped(_conn, (m) => '${m.group(1)}***${m.group(2)}');
}

/// Telefon raqami yashirilmaydi (unmasked) — mijozga bog'lanish uchun to'liq kerak.
String maskPhone(String p) => p;
