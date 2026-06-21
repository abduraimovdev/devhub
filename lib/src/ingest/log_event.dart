import 'package:devhub/src/core/registry.dart';
import 'package:devhub/src/core/scrub.dart';

/// Ilovadan kelgan log hodisasi (`POST /v1/log` body).
class LogEvent {
  LogEvent({
    required this.type,
    required this.message,
    this.level,
    this.statusCode,
    this.endpoint,
    this.context = const {},
    DateTime? ts,
  }) : ts = ts ?? DateTime.now().toUtc();

  final String type; // crash | error | api | freeze | login
  final String? level;
  final String message;
  final int? statusCode; // api uchun
  final String? endpoint; // route / url
  final Map<String, dynamic> context;
  final DateTime ts; // hodisa vaqti (UTC) — klient yuboradi yoki qabul vaqti

  static LogEvent fromJson(Map<String, dynamic> j) {
    final ctx = (j['context'] as Map?)?.cast<String, dynamic>() ?? const {};
    int? toInt(Object? v) => v is int ? v : int.tryParse('${v ?? ''}');
    return LogEvent(
      type: (j['type'] as String?)?.trim().toLowerCase() ?? 'error',
      level: j['level'] as String?,
      message: (j['message'] as String?) ?? '',
      statusCode: toInt(j['statusCode'] ?? ctx['statusCode']),
      endpoint: (j['endpoint'] ?? ctx['endpoint'] ?? ctx['route'] ?? ctx['url'])
          as String?,
      context: ctx,
      ts: DateTime.tryParse('${j['ts'] ?? ''}')?.toUtc(),
    );
  }
}

/// crash/freeze/login va 5xx — DOIM yuboriladi (docs/04 smart filtr).
bool isAlwaysSend(LogEvent e) {
  if (e.type == 'crash' || e.type == 'freeze' || e.type == 'login') return true;
  if (e.type == 'api' && (e.statusCode ?? 0) >= 500) return true;
  return false;
}

/// Anti-flood dedupe kaliti — project + type + endpoint + status + msg[:120].
String dedupeKey(int projectId, LogEvent e) {
  final msg =
      e.message.length > 120 ? e.message.substring(0, 120) : e.message;
  return '$projectId|${e.type}|${e.endpoint ?? ''}|${e.statusCode ?? ''}|$msg';
}

/// Login → Login topic; qolgani → Log topic.
int? routeTopic(LogEvent e, Project p) =>
    e.type == 'login' ? p.topicLogin : p.topicLog;

/// Telegram HTML xabari — maxfiy ma'lumot scrub qilinadi. To'liq log:
/// ilova, versiya, qurilma, qadam, sabab, telefon, vaqt (Toshkent).
String formatLogMessage(LogEvent e, {int suppressedBefore = 0}) {
  final head = StringBuffer('${_emoji(e)} <b>${_esc(e.type.toUpperCase())}</b>');
  if (e.statusCode != null) head.write(' ${e.statusCode}');
  if (e.endpoint != null && e.endpoint!.isNotEmpty) {
    head.write(' <code>${_esc(e.endpoint!)}</code>');
  }
  final body = StringBuffer('$head\n${_esc(Scrub.text(e.message))}');

  // Kontekst qatorlari — tartibli, faqat mavjud bo'lganlari (kalit → yorliq).
  const labels = <List<String>>[
    ['app', 'Ilova'],
    ['appVersion', 'Versiya'],
    ['device', 'Qurilma'],
    ['osVersion', 'OS'],
    ['step', 'Qadam'],
    ['reason', 'Sabab'],
    ['phone', 'Telefon'],
    ['userId', 'User'],
    ['method', 'Metod'],
  ];
  for (final l in labels) {
    final v = e.context[l[0]];
    if (v != null && '$v'.isNotEmpty) {
      body.write('\n<i>${l[1]}:</i> ${_esc(Scrub.text('$v'))}');
    }
  }
  final dur = e.context['durationMs'];
  if (dur != null) body.write('\n<i>Davomiyligi:</i> $dur ms');

  // Vaqt — Toshkent (UTC+5).
  body.write('\n<i>Vaqt:</i> ${_tashkentTime(e.ts)}');

  // Stack trace (crash/error) — qayerda xato bo'lganini ko'rsatadi.
  // Telegram limiti uchun qisqartiriladi, <pre> blokda.
  final stack = e.context['stack'];
  if (stack != null && '$stack'.trim().isNotEmpty) {
    body.write('\n\n<b>Stack:</b>\n<pre>${_esc(_trimStack('$stack'))}</pre>');
  }

  if (suppressedBefore > 0) {
    body.write('\n<i>(oldingi oynada yana ×$suppressedBefore bostirildi)</i>');
  }
  return body.toString();
}

/// Stack trace'ni Telegram xabari limiti uchun qisqartiradi — eng yuqori
/// freym'lar (xato kelib chiqqan joy) saqlanadi.
String _trimStack(String stack, {int maxLines = 20, int maxChars = 2000}) {
  var lines = stack.split('\n').where((l) => l.trim().isNotEmpty).toList();
  var truncated = false;
  if (lines.length > maxLines) {
    lines = lines.take(maxLines).toList();
    truncated = true;
  }
  var out = lines.join('\n');
  if (out.length > maxChars) {
    out = out.substring(0, maxChars);
    truncated = true;
  }
  return truncated ? '$out\n… (qisqartirildi)' : out;
}

/// UTC vaqtni Toshkent (UTC+5) ga o'girib `YYYY-MM-DD HH:MM:SS` formatlaydi.
String _tashkentTime(DateTime utc) {
  final t = utc.add(const Duration(hours: 5));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} '
      '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
}

String _emoji(LogEvent e) {
  switch (e.type) {
    case 'crash':
      return '💥';
    case 'freeze':
      return '🧊';
    case 'login':
      return '🔐';
    case 'api':
      return (e.statusCode ?? 0) >= 500 ? '🔴' : '🟠';
    default:
      return '⚠️';
  }
}

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
