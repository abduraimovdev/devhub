import 'dart:io';

import 'package:devhub/devhub.dart';
import 'package:devhub/src/ingest/bot.dart';
import 'package:devhub/src/ingest/server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Vazifa A — log ingest web + onboarding bot (DOIMIY ishlaydi).
/// `POST /v1/log` (server) va `/newproject` (bot) bir vaqtda ishlaydi.
Future<void> main() async {
  stdout.writeln('devhub · ingest+bot (A) — docs/02, docs/04');

  final Config cfg;
  try {
    cfg = Config.fromEnv();
  } on Object catch (e) {
    stderr.writeln('config: $e');
    exit(1);
  }
  if (cfg.registryDatabaseUrl.isEmpty) {
    stderr.writeln('config: REGISTRY_DATABASE_URL kerak (ingest+bot uchun)');
    exit(1);
  }

  final registry = PgRegistry(cfg.registryDatabaseUrl);
  await registry.bootstrap();

  final telegram = TelegramClient(
    botToken: cfg.botToken,
    chatId: cfg.logGroupChatId,
  );

  // 1) HTTP ingest serveri (serve darrov qaytadi, fonda tinglaydi).
  final ingest = IngestServer(registry: registry, telegram: telegram);
  final server = await shelf_io.serve(
    ingest.handler,
    InternetAddress.anyIPv4,
    cfg.port,
  );
  stdout.writeln('ingest: http://${server.address.address}:${server.port}');

  // 2) Telegram bot (long-polling — bloklaydi; server event-loop'da davom etadi).
  final bot = DevHubBot(config: cfg, registry: registry, telegram: telegram);
  await bot.start();
}
