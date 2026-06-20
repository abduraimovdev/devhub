import 'dart:io';

import 'package:devhub/devhub.dart';

/// Vazifa B — DB backup (CRON: bir marta ishlab-o'chadi).
/// Phase 2: nishonlar `DATABASES` env'dan. Phase 3 da registr (Postgres) dan.
Future<void> main() async {
  stdout.writeln('devhub · backup cron (B) — docs/03');

  final Config cfg;
  try {
    cfg = Config.fromEnv();
  } on Object catch (e) {
    stderr.writeln('config: $e');
    exit(1);
  }

  final telegram = TelegramClient(
    botToken: cfg.botToken,
    chatId: cfg.logGroupChatId,
  );
  final r2 = cfg.r2 == null ? null : R2Uploader(cfg.r2!);

  final targets = BackupRunner.targetsFromEnv(
    cfg.databasesEnv,
    backupTopicId: cfg.backupTopicId,
  );

  final runner = BackupRunner(config: cfg, telegram: telegram, r2: r2);
  await runner.run(targets);

  telegram.close();
  exit(0);
}
