import 'dart:io';

import 'package:devhub/src/backup/dump.dart';
import 'package:devhub/src/backup/r2_uploader.dart';
import 'package:devhub/src/core/config.dart';
import 'package:devhub/src/core/registry.dart';
import 'package:devhub/src/core/telegram.dart';

/// Vazifa B orkestratori: har DB ni dump → yuborish zanjiri → tozalash →
/// xulosa. Har nishon izolyatsiya — bittasi yiqilsa qolgani davom etadi.
class BackupRunner {
  BackupRunner({required this.config, required this.telegram, this.r2});

  final Config config;
  final TelegramClient telegram;
  final R2Uploader? r2;

  Future<void> run(List<BackupTarget> targets) async {
    if (targets.isEmpty) {
      stdout.writeln("backup: nishon yo'q (DATABASES/registr bo'sh)");
      return;
    }
    var ok = 0;
    var fail = 0;
    for (final t in targets) {
      final success = await _one(t);
      if (success) {
        ok++;
      } else {
        fail++;
      }
    }
    final emoji = fail == 0 ? '✅' : '⚠️';
    await _safeSend(
      config.backupTopicId,
      '$emoji Backup yakunlandi: $ok ✅ / $fail ❌ (${targets.length} DB)',
    );
  }

  Future<bool> _one(BackupTarget t) async {
    final topic = t.topicBackup ?? config.backupTopicId;
    stdout.writeln('backup: ${t.name} ...');

    final res = await dumpDatabase(
      name: t.name,
      dbUrl: t.dbUrl,
      timeout: config.pgDumpTimeout,
    );

    if (!res.ok) {
      await _safeSend(
        topic,
        '❌ <b>${t.name}</b> dump xato:\n<pre>${_esc(res.error ?? '')}</pre>',
      );
      return false;
    }

    final file = res.file!;
    final caption = backupCaption(t.name, DateTime.now().toUtc(), res.bytes);
    final tooBig = res.bytes > config.maxTelegramMb * 1024 * 1024;

    try {
      // 1) Telegram (≤ maxTelegramMb bo'lsa)
      if (!tooBig) {
        final sent = await telegram.sendDocument(topic, file, caption: caption);
        if (sent) return true;
      }
      // 2) R2 fallback (katta yoki Telegram yuborolmadi)
      if (r2 != null) {
        try {
          final key = 'backups/${t.name}/${file.uri.pathSegments.last}';
          final link = await r2!.upload(file, key);
          await _safeSend(
            topic,
            '📦 <b>${t.name}</b> backup (${humanSize(res.bytes)}):\n$link',
          );
          return true;
        } on Object catch (e) {
          await _safeSend(
            topic,
            '❌ <b>${t.name}</b> R2 yuklash xato:\n<pre>${_esc('$e')}</pre>',
          );
          return false;
        }
      }
      // 3) R2 sozlanmagan
      await _safeSend(
        topic,
        '❌ <b>${t.name}</b> yuborilmadi (${humanSize(res.bytes)} — '
        'Telegram limiti, R2 sozlanmagan)',
      );
      return false;
    } finally {
      await _safeDelete(file);
    }
  }

  Future<void> _safeSend(int? topic, String text) async {
    try {
      await telegram.sendMessage(topic, text);
    } on Object catch (e) {
      stdout.writeln('telegram sendMessage xato: $e');
    }
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } on Object {
      // best-effort
    }
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  /// Phase 2 bootstrap: `DATABASES` env → nishonlar (har qatorda `label=url`).
  /// Phase 3 da registr (Postgres) bu manbani almashtiradi. Sof — test qilinadi.
  static List<BackupTarget> targetsFromEnv(
    String? databases, {
    int? backupTopicId,
  }) {
    if (databases == null || databases.trim().isEmpty) return [];
    final out = <BackupTarget>[];
    for (final raw in databases.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final name = line.substring(0, eq).trim();
      final url = line.substring(eq + 1).trim();
      if (name.isEmpty || url.isEmpty) continue;
      out.add(BackupTarget(name: name, dbUrl: url, topicBackup: backupTopicId));
    }
    return out;
  }
}
