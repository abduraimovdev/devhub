import 'dart:io';

import 'package:devhub/devhub.dart';

/// Vazifa B — DB backup (CRON: bir marta ishlab-o'chadi).
///
/// Nishonlar **registr (Postgres)** dan keladi — `/addbackup` qo'shgan faol
/// DB'lar (docs/07). Registr bo'sh yoki ulanmasa, `DATABASES` env'ga
/// qaytadi (Phase 2 bootstrap). Shu tufayli yangi loyiha qo'shish uchun
/// redeploy SHART EMAS — bot `/addbackup` qiladi, keyingi cron uni oladi.
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

  // 1) Registrdan (Postgres) — `/addbackup` qo'shgan faol nishonlar.
  var targets = <BackupTarget>[];
  PgRegistry? registry;
  if (cfg.registryDatabaseUrl.isNotEmpty) {
    try {
      registry = PgRegistry(cfg.registryDatabaseUrl);
      await registry.bootstrap();
      targets = await registry.activeBackupTargets();
      stdout.writeln('backup: registrdan ${targets.length} nishon');
    } on Object catch (e) {
      stderr.writeln('registry: $e (DATABASES env ga qaytamiz)');
    }
  }

  // 2) Registr bo'sh/ulanmadi — `DATABASES` env (Phase 2 bootstrap).
  if (targets.isEmpty) {
    targets = BackupRunner.targetsFromEnv(
      cfg.databasesEnv,
      backupTopicId: cfg.backupTopicId,
    );
    if (targets.isNotEmpty) {
      stdout.writeln('backup: DATABASES env dan ${targets.length} nishon');
    }
  }

  final runner = BackupRunner(config: cfg, telegram: telegram, r2: r2);
  await runner.run(targets);

  await registry?.close();
  telegram.close();
  exit(0);
}
