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
  });

  final String type; // crash | error | api | freeze | login
  final String? level;
  final String message;
  final int? statusCode; // api uchun
  final String? endpoint; // route / url
  final Map<String, dynamic> context;

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

/// Telegram HTML xabari — maxfiy ma'lumot scrub qilinadi.
String formatLogMessage(LogEvent e, {int suppressedBefore = 0}) {
  final head = StringBuffer('${_emoji(e)} <b>${_esc(e.type.toUpperCase())}</b>');
  if (e.statusCode != null) head.write(' ${e.statusCode}');
  if (e.endpoint != null && e.endpoint!.isNotEmpty) {
    head.write(' <code>${_esc(e.endpoint!)}</code>');
  }
  final body = StringBuffer('$head\n${_esc(Scrub.text(e.message))}');
  for (final k in const [
    'method',
    'durationMs',
    'appVersion',
    'device',
    'userId',
  ]) {
    final v = e.context[k];
    if (v != null) body.write('\n<i>$k</i>: ${_esc(Scrub.text('$v'))}');
  }
  if (suppressedBefore > 0) {
    body.write('\n<i>(oldingi oynada yana ×$suppressedBefore bostirildi)</i>');
  }
  return body.toString();
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
