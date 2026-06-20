import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:devhub/src/core/registry.dart';
import 'package:devhub/src/core/telegram.dart';
import 'package:devhub/src/ingest/filter.dart';
import 'package:devhub/src/ingest/log_event.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Log ingest HTTP servisi (Vazifa A). `POST /v1/log`, `/v1/log/batch`,
/// `GET /health`. API key bo'yicha loyihaga marshrutlaydi, filtr + scrub
/// qo'llaydi, Telegram topic'ga yuboradi (fire-and-forget → 202).
class IngestServer {
  IngestServer({
    required this.registry,
    required this.telegram,
    LogFilter? filter,
  }) : filter = filter ?? LogFilter();

  final PgRegistry registry;
  final TelegramClient telegram;
  final LogFilter filter;

  static const Duration _cacheTtl = Duration(minutes: 5);
  final Map<String, _CachedProject> _cache = {};

  static const Map<String, String> _cors = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, X-Api-Key',
  };

  Handler get handler {
    final router = Router()
      ..get('/health', (Request r) => Response.ok('ok'))
      ..post('/v1/log', _log)
      ..post('/v1/log/batch', _batch);
    // CORS — admin (Flutter Web) brauzeridan cross-origin POST uchun.
    Middleware corsMw() => (inner) => (req) async {
          if (req.method == 'OPTIONS') {
            return Response.ok('', headers: _cors);
          }
          final res = await inner(req);
          return res.change(headers: _cors);
        };
    return const Pipeline().addMiddleware(corsMw()).addHandler(router.call);
  }

  Future<Project?> _resolve(String? apiKey, DateTime now) async {
    if (apiKey == null || apiKey.isEmpty) return null;
    final cached = _cache[apiKey];
    if (cached != null && now.isBefore(cached.expiry)) return cached.project;
    final p = await registry.projectByApiKey(apiKey);
    if (p != null) _cache[apiKey] = _CachedProject(p, now.add(_cacheTtl));
    return p;
  }

  Future<Response> _log(Request req) async {
    final now = DateTime.now();
    final project = await _resolve(req.headers['x-api-key'], now);
    if (project == null) return Response.forbidden('invalid api key');
    try {
      final json = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      _ingestOne(project, LogEvent.fromJson(json), now);
    } on Object {
      return Response(400, body: 'bad json');
    }
    return Response(202);
  }

  Future<Response> _batch(Request req) async {
    final now = DateTime.now();
    final project = await _resolve(req.headers['x-api-key'], now);
    if (project == null) return Response.forbidden('invalid api key');
    try {
      final json = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
      final events = (json['events'] as List).cast<Map<String, dynamic>>();
      for (final e in events) {
        _ingestOne(project, LogEvent.fromJson(e), now);
      }
    } on Object {
      return Response(400, body: 'bad json');
    }
    return Response(202);
  }

  void _ingestOne(Project project, LogEvent e, DateTime now) {
    final decision = filter.decide(
      dedupeKey(project.id, e),
      alwaysSend: isAlwaysSend(e),
      now: now,
    );
    if (!decision.send) return;
    final text =
        formatLogMessage(e, suppressedBefore: decision.suppressedBefore);
    // Fire-and-forget — klient kutmaydi (202 darrov qaytadi).
    unawaited(
      telegram.sendMessage(routeTopic(e, project), text).catchError(
        (Object err) => stdout.writeln('ingest send xato: $err'),
      ),
    );
  }
}

class _CachedProject {
  _CachedProject(this.project, this.expiry);
  final Project project;
  final DateTime expiry;
}
