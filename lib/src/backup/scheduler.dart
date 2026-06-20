import 'dart:async';
import 'dart:io';

/// Always-on ingest servis ICHIDA backup'ni jadval bo'yicha ishga tushiradi —
/// alohida cron servis o'rniga (bitta servisli sozlamalar uchun).
///
/// UTC soatlari [hoursUtc] (masalan `[0, 17]` = 05:00 / 22:00 Toshkent)
/// bo'yicha kuniga bir marta (daqiqa = 00) [run] chaqiriladi. Slot kuniga bir
/// marta ishlaydi (xotirada belgilanadi); ish davom etayotganda qayta
/// chaqirilmaydi.
class BackupScheduler {
  BackupScheduler({
    required this.hoursUtc,
    required this.run,
    this.checkInterval = const Duration(seconds: 30),
  });

  /// Backup ishga tushadigan UTC soatlari (0–23).
  final List<int> hoursUtc;

  /// Bajariladigan ish (odatda `BackupRunner.run`).
  final Future<void> Function() run;

  /// Jadvalni qanchada bir tekshirish (daqiqa=00 ni o'tkazib yubormaslik
  /// uchun < 60s bo'lsin).
  final Duration checkInterval;

  final Set<String> _doneSlots = <String>{}; // 'YYYY-M-D-H'
  Timer? _timer;
  bool _running = false;

  /// Jadvalni ishga tushiradi. [hoursUtc] bo'sh bo'lsa — hech narsa qilmaydi.
  void start() {
    if (hoursUtc.isEmpty) return;
    stdout.writeln(
      'backup scheduler: in-process, UTC soat(lar) ${hoursUtc.join(",")}',
    );
    _timer = Timer.periodic(checkInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (_running) return;
    final now = DateTime.now().toUtc();
    if (now.minute != 0 || !hoursUtc.contains(now.hour)) return;
    final slot = '${now.year}-${now.month}-${now.day}-${now.hour}';
    if (_doneSlots.contains(slot)) return;
    _doneSlots
      ..clear() // faqat bitta (oxirgi) slotni eslab qolamiz — xotira o'smaydi
      ..add(slot);
    _running = true;
    stdout.writeln('backup scheduler: $slot — ishga tushdi');
    try {
      await run();
    } on Object catch (e) {
      stdout.writeln('backup scheduler xato: $e');
    } finally {
      _running = false;
    }
  }

  void stop() => _timer?.cancel();
}
