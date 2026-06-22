import 'dart:io';

import 'package:devhub/devhub.dart';
import 'package:devhub/src/backup/scheduler.dart';
import 'package:devhub/src/ingest/bot.dart';
import 'package:devhub/src/ingest/server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

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

  final ingest = IngestServer(registry: registry, telegram: telegram);
  final server = await shelf_io.serve(
    ingest.handler,
    InternetAddress.anyIPv4,
    cfg.port,
  );
  stdout.writeln('ingest: http://${server.address.address}:${server.port}');

  final backupHours = (Platform.environment['BACKUP_CRON_HOURS_UTC'] ?? '')
      .split(',')
      .map((s) => int.tryParse(s.trim()))
      .whereType<int>()
      .where((h) => h >= 0 && h <= 23)
      .toList();
  if (backupHours.isNotEmpty) {
    final r2 = cfg.r2 == null ? null : R2Uploader(cfg.r2!);
    final runner = BackupRunner(config: cfg, telegram: telegram, r2: r2);
    BackupScheduler(
      hoursUtc: backupHours,
      run: () async {
        var targets = await registry.activeBackupTargets();
        if (targets.isEmpty) {
          targets = BackupRunner.targetsFromEnv(
            cfg.databasesEnv,
            backupTopicId: cfg.backupTopicId,
          );
        }
        await runner.run(targets);
      },
    ).start();
  }

  final bot = DevHubBot(config: cfg, registry: registry, telegram: telegram);
  await bot.start();
}
