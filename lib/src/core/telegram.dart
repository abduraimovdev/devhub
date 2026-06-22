import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class TelegramClient {
  TelegramClient({
    required this.botToken,
    required this.chatId,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String botToken;
  final int chatId;
  final http.Client _client;

  String get _base => 'https://api.telegram.org/bot$botToken';

  Future<void> sendMessage(int? threadId, String text) async {
    final resp = await _client.post(
      Uri.parse('$_base/sendMessage'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chat_id': chatId,
        if (threadId != null) 'message_thread_id': threadId,
        'text': text,
        'parse_mode': 'HTML',
        'disable_web_page_preview': true,
      }),
    );
    if (resp.statusCode != 200) {
      throw TelegramException('sendMessage ${resp.statusCode}: ${resp.body}');
    }
  }

  Future<bool> sendDocument(
    int? threadId,
    File file, {
    String? caption,
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/sendDocument'),
      );
      req.fields['chat_id'] = '$chatId';
      if (threadId != null) req.fields['message_thread_id'] = '$threadId';
      if (caption != null) req.fields['caption'] = caption;
      req.files.add(await http.MultipartFile.fromPath('document', file.path));
      final streamed = await _client.send(req);
      final resp = await http.Response.fromStream(streamed);
      return resp.statusCode == 200;
    } on Object {
      return false;
    }
  }

  Future<int> createForumTopic(String name) async {
    final resp = await _client.post(
      Uri.parse('$_base/createForumTopic'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'chat_id': chatId, 'name': name}),
    );
    final body = jsonDecode(resp.body);
    if (resp.statusCode != 200 || body is! Map || body['ok'] != true) {
      throw TelegramException('createForumTopic: ${resp.body}');
    }
    return (body['result'] as Map)['message_thread_id'] as int;
  }

  void close() => _client.close();
}

class TelegramException implements Exception {
  TelegramException(this.message);
  final String message;
  @override
  String toString() => 'TelegramException: $message';
}
