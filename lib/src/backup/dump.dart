import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// `pg_dump` natijasi.
class DumpResult {
  DumpResult.success(this.file, this.bytes)
      : ok = true,
        error = null;
  DumpResult.failure(this.error)
      : ok = false,
        file = null,
        bytes = 0;

  final bool ok;
  final File? file;
  final int bytes;
  final String? error;
}

/// `pg_dump --no-owner --no-privileges <url>` → gzip (dart:io, cross-platform,
/// `gzip` binary'siz) → `Directory.systemTemp` ichidagi `.sql.gz` fayl.
///
/// `gzip`ni Dart kodекс bilan qilamiz — Windows'da ham binary kerak emas.
/// `pg_dump` esa native (Docker image'da bor; lokal Windows'da Docker orqali).
Future<DumpResult> dumpDatabase({
  required String name,
  required String dbUrl,
  required Duration timeout,
  DateTime? now,
}) async {
  final ts = (now ?? DateTime.now()).toUtc();
  final outPath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      '${backupFileName(name, ts)}';
  final outFile = File(outPath);

  Process? proc;
  try {
    proc = await Process.start('pg_dump', [
      '--no-owner',
      '--no-privileges',
      dbUrl,
    ]);

    final stderrBuf = StringBuffer();
    final stderrDone =
        proc.stderr.transform(utf8.decoder).forEach(stderrBuf.write);

    final sink = outFile.openWrite();
    final pipe = proc.stdout.transform(gzip.encoder).pipe(sink);

    try {
      await pipe.timeout(timeout);
    } on TimeoutException {
      proc.kill(ProcessSignal.sigkill);
      await _safeDelete(outFile);
      return DumpResult.failure('pg_dump timeout (${timeout.inSeconds}s)');
    }

    final code = await proc.exitCode;
    await stderrDone;

    if (code != 0) {
      await _safeDelete(outFile);
      return DumpResult.failure(tailLines(stderrBuf.toString()));
    }

    final bytes = await outFile.length();
    if (bytes < 1024) {
      // Juda kichik — ehtimol bo'sh/buzilgan dump.
      return DumpResult.failure(
        'dump juda kichik ($bytes bayt) — ehtimol bo\'sh DB yoki xato',
      );
    }
    return DumpResult.success(outFile, bytes);
  } on Object catch (e) {
    proc?.kill(ProcessSignal.sigkill);
    await _safeDelete(outFile);
    return DumpResult.failure(e.toString());
  }
}

Future<void> _safeDelete(File f) async {
  try {
    if (f.existsSync()) await f.delete();
  } on Object {
    // jim — tozalash best-effort
  }
}

/// `label_YYYY-MM-DD_HH-MM.sql.gz` (UTC). Sof — test qilinadi.
String backupFileName(String name, DateTime utc) {
  String two(int n) => n.toString().padLeft(2, '0');
  final d = utc;
  return '${name}_${d.year}-${two(d.month)}-${two(d.day)}'
      '_${two(d.hour)}-${two(d.minute)}.sql.gz';
}

/// Telegram caption. Sof — test qilinadi.
String backupCaption(String name, DateTime utc, int bytes) {
  return '✅ <b>$name</b>\n🕒 ${utc.toIso8601String()}\n📦 ${humanSize(bytes)}';
}

/// Baytni odam o'qiydigan ko'rinishga. Sof — test qilinadi.
String humanSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  return '${size.toStringAsFixed(1)} ${units[i]}';
}

/// Matnning oxirgi [n] qatori (pg_dump xatosini qisqartirib yuborish uchun).
String tailLines(String text, [int n = 6]) {
  final lines =
      text.trim().split('\n').where((l) => l.trim().isNotEmpty).toList();
  if (lines.length <= n) return lines.join('\n');
  return lines.sublist(lines.length - n).join('\n');
}
