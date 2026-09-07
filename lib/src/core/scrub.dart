class Scrub {
  Scrub._();

  static final RegExp _bearer = RegExp(r'([Bb]earer\s+)[A-Za-z0-9._\-]+');
  static final RegExp _tokenKv = RegExp(
    r'("?(?:token|secret|api[_-]?key|access[_-]?key|authorization)"?\s*[:=]\s*"?)[^"\s,}]+',
    caseSensitive: false,
  );
  static final RegExp _connPw = RegExp(r'(://[^:/\s]+:)[^@/\s]+(@)');

  static String text(String input) {
    var out = input;
    out = out.replaceAllMapped(_bearer, (m) => '${m.group(1)}***');
    out = out.replaceAllMapped(_tokenKv, (m) => '${m.group(1)}***');
    out = out.replaceAllMapped(_connPw, (m) => '${m.group(1)}***${m.group(2)}');
    return out;
  }

  /// Telefon raqami yashirilmaydi (unmasked) — mijozga bog'lanish uchun to'liq kerak.
  static String phone(String p) => p;
}
