import 'dart:async';

import 'package:devlog_client/src/device_info.dart';
import 'package:devlog_client/src/log_event.dart';
import 'package:devlog_client/src/scrub.dart';
import 'package:devlog_client/src/sender.dart';
import 'package:flutter/foundation.dart';

/// devhub log klienti — fasad. App startup'da `DevLog.init(...)` chaqiriladi.
///
/// ```dart
/// void main() {
///   DevLog.init(app: 'POS', apiKey: '...', appVersion: '1.0.0+4');
///   runZonedGuarded(() => runApp(const App()), DevLog.zoneError);
/// }
/// ```
class DevLog {
  DevLog._();

  static DevLogSender? _sender;
  static String? _app;
  static String? _appVersion;
  static String? _device;

  static void init({
    required String baseUrl,
    required String apiKey,
    String? app,
    String? appVersion,
    bool captureCrashes = true,
  }) {
    _app = app;
    _appVersion = appVersion;
    _sender = DevLogSender(baseUrl: baseUrl, apiKey: apiKey);
    // Qurilma modelini fonда aniqlaymiz — keyingi loglarга `device` qo'shiladi.
    unawaited(_detectDevice());
    if (captureCrashes) _installCrashHandlers();
  }

  static Future<void> _detectDevice() async {
    try {
      _device = await resolveDeviceLabel();
    } on Object {
      // device aniqlanmasa ham log ishlayveradi — jim.
    }
  }

  /// Umumiy xato.
  static void error(String message, {Map<String, dynamic>? context}) =>
      _enqueue('error', message, context);

  /// API non-2xx javobi (200/201 e'tiborga olinmaydi). Dio/Serverpod
  /// interceptor'idan yoki qo'lda chaqiriladi (README'ga qarang).
  static void apiError({
    required int statusCode,
    String method = '',
    String url = '',
    String? message,
    int? durationMs,
  }) {
    if (statusCode == 200 || statusCode == 201) return;
    _enqueue(
      'api',
      message ?? '$method $url → $statusCode'.trim(),
      {
        'statusCode': statusCode,
        if (method.isNotEmpty) 'method': method,
        if (url.isNotEmpty) 'url': url,
        if (durationMs != null) 'durationMs': durationMs,
      },
    );
  }

  /// Login natijasi yoki urinishi (telefon avtomatik maskalanadi).
  ///
  /// [step] — qaysi bosqich: `telefon` | `OTP` | `PIN` | `parol`.
  /// [reason] — muvaffaqiyatsizlik sababi (xato matni).
  static void login({
    required bool success,
    String? phone,
    String? step,
    String? reason,
    Map<String, dynamic>? context,
  }) {
    _enqueue('login', success ? 'login ✅' : 'login urinishi ❌', {
      if (phone != null) 'phone': maskPhone(phone),
      'success': success,
      if (step != null) 'step': step,
      if (reason != null) 'reason': reason,
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
          if (_app != null) 'app': _app,
          if (_appVersion != null) 'appVersion': _appVersion,
          if (_device != null) 'device': _device,
          ...?context,
        },
      ),
    );
  }

  static void _installCrashHandlers() {
    // Mavjud handlerlar (masalan Sentry) BUZILMASIN — zanjirlaymiz.
    final prevFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      _crash(details.exception, details.stack);
      prevFlutter?.call(details);
    };
    final prevPlatform = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _crash(error, stack);
      return prevPlatform?.call(error, stack) ?? false;
    };
  }
}
