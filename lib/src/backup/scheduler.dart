import 'dart:async';
import 'dart:io';

class BackupScheduler {
  BackupScheduler({
    required this.hoursUtc,
    required this.run,
    this.checkInterval = const Duration(seconds: 30),
  });

  final List<int> hoursUtc;

  final Future<void> Function() run;

  final Duration checkInterval;

  final Set<String> _doneSlots = <String>{};
  Timer? _timer;
  bool _running = false;

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
      ..clear()
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
