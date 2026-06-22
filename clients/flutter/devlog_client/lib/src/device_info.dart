import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

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
