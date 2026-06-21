import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Inson o'qiydigan qurilma yorlig'i — har log "device" kontekstiga qo'shiladi.
///
/// Misollar:
/// - Android: `samsung SM-S928B (Android 14)`
/// - Windows: `Windows 11 Pro (KASSA-1)`
/// - iOS:     `iPhone16,2 (iOS 17.5)`
/// - macOS:   `MacBookPro18,1 (macOS 14.5)`
/// - Web:     `chrome · Windows`
///
/// Xato bo'lsa (plugin yo'q va h.k.) platforma nomini qaytaradi — hech qachon
/// throw qilmaydi (log oqimini buzmaslik uchun).
Future<String> resolveDeviceLabel() async {
  final info = DeviceInfoPlugin();
  try {
    if (kIsWeb) {
      final w = await info.webBrowserInfo;
      return '${w.browserName.name} · ${w.platform ?? 'web'}';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final a = await info.androidInfo;
        return '${a.brand} ${a.model} (Android ${a.version.release})';
      case TargetPlatform.iOS:
        final i = await info.iosInfo;
        return '${i.utsname.machine} (iOS ${i.systemVersion})';
      case TargetPlatform.windows:
        final w = await info.windowsInfo;
        return '${w.productName} (${w.computerName})';
      case TargetPlatform.macOS:
        final m = await info.macOsInfo;
        return '${m.model} (macOS ${m.osRelease})';
      case TargetPlatform.linux:
        final l = await info.linuxInfo;
        return l.prettyName;
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  } on Object {
    return defaultTargetPlatform.name;
  }
}
