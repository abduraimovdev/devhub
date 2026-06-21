/// Maxfiy ma'lumotni Telegram'ga yuborishdan OLDIN maskalaydi.
///
/// Loglar (xato matni, context JSON) ichidagi token/parol/connection-string
/// va shu kabilarni `***` bilan almashtiradi. Sof funksiya — test qilinadi.
class Scrub {
  Scrub._();

  static final RegExp _bearer = RegExp(r'([Bb]earer\s+)[A-Za-z0-9._\-]+');
  static final RegExp _kv = RegExp(
    r'("?(?:password|passwd|pin|otp|code|phone|token|secret|api[_-]?key|access[_-]?key|authorization)"?\s*[:=]\s*"?)[^"\s,}]+',
    caseSensitive: false,
  );
  static final RegExp _connPw = RegExp(r'(://[^:/\s]+:)[^@/\s]+(@)');

  /// Matndagi sirlarni `***` bilan almashtiradi.
  static String text(String input) {
    var out = input;
    out = out.replaceAllMapped(_bearer, (m) => '${m.group(1)}***');
    out = out.replaceAllMapped(_kv, (m) => '${m.group(1)}***');
    out = out.replaceAllMapped(_connPw, (m) => '${m.group(1)}***${m.group(2)}');
    return out;
  }

  /// Telefonni qisman yashiradi: `+998901234567` → `+99890***4567`.
  static String phone(String p) {
    if (p.length < 8) return p;
    return '${p.substring(0, p.length - 7)}***${p.substring(p.length - 4)}';
  }
}
