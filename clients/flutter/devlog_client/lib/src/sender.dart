import 'dart:async';
import 'dart:convert';

import 'package:devlog_client/src/log_event.dart';
import 'package:http/http.dart' as http;

class DevLogSender {
  DevLogSender({
    required this.baseUrl,
    required this.apiKey,
    this.dbIngestUrl,
    http.Client? client,
    this.maxQueue = 200,
    this.batchSize = 50,
    this.flushInterval = const Duration(seconds: 3),
  }) : _client = client ?? http.Client() {
    _timer = Timer.periodic(flushInterval, (_) => flush());
  }

  final String baseUrl;
  final String apiKey;
  String? dbIngestUrl;
  final int maxQueue;
  final int batchSize;
  final Duration flushInterval;
  final http.Client _client;

  final List<DevLogEvent> _queue = [];
  Timer? _timer;
  bool _sending = false;

  void enqueue(DevLogEvent e) {
    if (_queue.length >= maxQueue) _queue.removeAt(0);
    _queue.add(e.scrubbed());
  }

  Future<void> flush() async {
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    final batch = _queue.take(batchSize).toList();
    try {
      // 1. DevHub (Telegram bot) ga yuborish
      if (baseUrl.isNotEmpty && apiKey.isNotEmpty) {
        try {
          await _client
              .post(
                Uri.parse('$baseUrl/v1/log/batch'),
                headers: {
                  'Content-Type': 'application/json',
                  'X-Api-Key': apiKey,
                },
                body: jsonEncode({
                  'events': batch.map((e) => e.toJson()).toList(),
                }),
              )
              .timeout(const Duration(seconds: 10));
        } on Object {/* devhub xatoligi DB yozilishiga to'sqinlik qilmasin */}
      }

      // 2. Go Backend (PostgreSQL) ga yuborish
      final dbUrl = dbIngestUrl;
      if (dbUrl != null && dbUrl.isNotEmpty) {
        try {
          await _client
              .post(
                Uri.parse(dbUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'events': batch.map((e) {
                    final ctx = Map<String, dynamic>.from(e.context);
                    final app = ctx.remove('app')?.toString() ?? '';
                    final appVer = ctx.remove('appVersion')?.toString() ?? '';
                    final dev = ctx.remove('device')?.toString() ?? '';
                    final ph = ctx.remove('phone')?.toString() ?? '';
                    var status = ctx['status']?.toString();
                    if (status == null) {
                      if (ctx['success'] == true) {
                        status = 'success';
                      } else if (ctx['success'] == false) {
                        status = 'failed';
                      } else if (ctx['statusCode'] != null) {
                        status = ctx['statusCode'].toString();
                      }
                    }
                    return {
                      'type': e.type,
                      'category': e.type == 'login' ? 'login' : 'log',
                      'app': app,
                      'appVersion': appVer,
                      'device': dev,
                      'phone': ph,
                      'message': e.message,
                      if (status != null) 'status': status,
                      'context': ctx,
                      'createdAt': e.createdAt.toUtc().toIso8601String(),
                    };
                  }).toList(),
                }),
              )
              .timeout(const Duration(seconds: 10));
        } on Object {/* DB xatoligi ilova ishlashiga ta'sir qilmasin */}
      }

      _queue.removeRange(0, batch.length);
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _client.close();
  }
}
