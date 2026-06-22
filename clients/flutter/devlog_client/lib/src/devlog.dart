import 'dart:async';

import 'package:devlog_client/src/device_info.dart';
import 'package:devlog_client/src/log_event.dart';
import 'package:devlog_client/src/scrub.dart';
import 'package:devlog_client/src/sender.dart';
import 'package:flutter/foundation.dart';

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

    unawaited(_detectDevice());
    if (captureCrashes) _installCrashHandlers();
  }

  static Future<void> _detectDevice() async {
    try {
      _device = await resolveDeviceLabel();
    } on Object {}
  }

  static void error(String message, {Map<String, dynamic>? context}) =>
      _enqueue('error', message, context);

  static void apiError({
    required int statusCode,
    String method = '',
    String url = '',
    String? message,
    String? request,
    String? response,
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
        if (request != null && request.isNotEmpty) 'request': request,
        if (response != null && response.isNotEmpty) 'response': response,
        if (durationMs != null) 'durationMs': durationMs,
      },
    );
  }

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

  static void freeze(int frameMs) =>
      _enqueue('freeze', 'UI qotdi: ${frameMs}ms', {'frameMs': frameMs});

  static void zoneError(Object error, StackTrace stack) => _crash(error, stack);

  static void _crash(Object error, StackTrace? stack) =>
      _enqueue('crash', error.toString(), {'stack': stack?.toString()});

  static void _enqueue(
    String type,
    String message,
    Map<String, dynamic>? context,
  ) {
    final s = _sender;
    if (s == null) return;
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
