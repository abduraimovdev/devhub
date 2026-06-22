import 'dart:async';
import 'dart:convert';

import 'package:devlog_client/src/log_event.dart';
import 'package:http/http.dart' as http;

class DevLogSender {
  DevLogSender({
    required this.baseUrl,
    required this.apiKey,
    http.Client? client,
    this.maxQueue = 200,
    this.batchSize = 50,
    this.flushInterval = const Duration(seconds: 3),
  }) : _client = client ?? http.Client() {
    _timer = Timer.periodic(flushInterval, (_) => flush());
  }

  final String baseUrl;
  final String apiKey;
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
      final resp = await _client
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
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        _queue.removeRange(0, batch.length);
      }
    } on Object {
    } finally {
      _sending = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _client.close();
  }
}
