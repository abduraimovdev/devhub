class Scrub {
  Scrub._();

  static final RegExp _bearer = RegExp(r'([Bb]earer\s+)[A-Za-z0-9._\-]+');
  static final RegExp _kv = RegExp(
    r'("?(?:password|passwd|pin|otp|code|phone|token|secret|api[_-]?key|access[_-]?key|authorization)"?\s*[:=]\s*"?)[^"\s,}]+',
    caseSensitive: false,
  );
  static final RegExp _connPw = RegExp(r'(://[^:/\s]+:)[^@/\s]+(@)');

  static String text(String input) {
    var out = input;
    out = out.replaceAllMapped(_bearer, (m) => '${m.group(1)}***');
    out = out.replaceAllMapped(_kv, (m) => '${m.group(1)}***');
    out = out.replaceAllMapped(_connPw, (m) => '${m.group(1)}***${m.group(2)}');
    return out;
  }

  static String phone(String p) {
    if (p.length < 8) return p;
    return '${p.substring(0, p.length - 7)}***${p.substring(p.length - 4)}';
  }
}
