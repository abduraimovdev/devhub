import 'package:devlog_client/src/log_event.dart';
import 'package:devlog_client/src/scrub.dart';
import 'package:devlog_client/src/sender.dart';
import 'package:flutter/foundation.dart';

/// devhub log klienti — fasad. App startup'da `DevLog.init(...)` chaqiriladi.
///
/// ```dart
/// void main() {
///   DevLog.init(baseUrl: '...', apiKey: '...', appVersion: '1.0.0+4');
///   runZonedGuarded(() => runApp(const App()), DevLog.zoneError);
/// }
/// ```
class DevLog {
  DevLog._();

  static DevLogSender? _sender;
  static String? _appVersion;

  static void init({
    required String baseUrl,
    required String apiKey,
    String? appVersion,
    bool captureCrashes = true,
  }) {
    _appVersion = appVersion;
    _sender = DevLogSender(baseUrl: baseUrl, apiKey: apiKey);
    if (captureCrashes) _installCrashHandlers();
  }

  /// Umumiy xato.
  static void error(String message, {Map<String, dynamic>? context}) =>
      _enqueue('error', message, context);

  /// API non-2xx javobi (200/201 e'tiborga olinmaydi). Dio/Serverpod
  /// interceptor'idan yoki qo'lda chaqiriladi (README'ga qarang).
  static void apiError({
    required int statusCode,
    required String method,
    required String url,
    String? message,
    int? durationMs,
  }) {
    if (statusCode == 200 || statusCode == 201) return;
    _enqueue('api', message ?? '$method $url → $statusCode', {
      'statusCode': statusCode,
      'method': method,
      'url': url,
      if (durationMs != null) 'durationMs': durationMs,
    });
  }

  /// Login natijasi yoki urinishi (telefon avtomatik maskalanadi).
  static void login({
    required bool success,
    String? phone,
    Map<String, dynamic>? context,
  }) {
    _enqueue('login', success ? 'login ✅' : 'login urinishi ❌', {
      if (phone != null) 'phone': maskPhone(phone),
      'success': success,
      ...?context,
    });
  }

  /// UI qotishi (freeze) — watchdog/kadr-vaqti hisoblagichidan.
  static void freeze(int frameMs) =>
      _enqueue('freeze', 'UI qotdi: ${frameMs}ms', {'frameMs': frameMs});

  /// `runZonedGuarded` uchun xato handleri.
  static void zoneError(Object error, StackTrace stack) =>
      _crash(error, stack);

  static void _crash(Object error, StackTrace? stack) =>
      _enqueue('crash', error.toString(), {'stack': stack?.toString()});

  static void _enqueue(
    String type,
    String message,
    Map<String, dynamic>? context,
  ) {
    final s = _sender;
    if (s == null) return; // init qilinmagan — jim
    s.enqueue(
      DevLogEvent(
        type: type,
        message: message,
        context: {
          if (_appVersion != null) 'appVersion': _appVersion,
          ...?context,
        },
      ),
    );
  }

  static void _installCrashHandlers() {
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      _crash(details.exception, details.stack);
      prev?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      _crash(error, stack);
      return false; // default ishlov ham davom etsin
    };
  }
}
