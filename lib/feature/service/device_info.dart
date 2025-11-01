// /feature/service/device_info.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:device_info_plus/device_info_plus.dart';

class ApiHost {
  static const String _override =
  String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');

  static Future<bool> _isEmulator() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        final model = (a.model).toLowerCase();
        final product = (a.product).toLowerCase();
        return model.contains('sdk') || product.contains('sdk') || model.contains('emulator');
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return i.isPhysicalDevice == false;
      }
    } catch (_) {}
    return false;
  }

  static Future<String> resolve() async {
    // 1) Explicit override via --dart-define
    if (_override.isNotEmpty) return _normalize(_override);

    // 2) In release, FORCE a public URL (Render)
    if (kReleaseMode) {
      // ✅ Put your Render API base here OR enforce dart-define strictly.
      return _normalize('https://online-svm-system-39bf.onrender.com');
      // Or throw to enforce:
      // throw StateError('BACKEND_BASE_URL not set for release build');
    }

    // 3) Dev defaults
    if (kIsWeb) return _normalize('http://localhost:3000');

    if (Platform.isAndroid) {
      return (await _isEmulator())
          ? _normalize('http://10.0.2.2:3000')
          : _normalize('http://192.168.11.43:3000'); // your LAN when testing on device
    }

    if (Platform.isIOS) {
      return (await _isEmulator())
          ? _normalize('http://localhost:3000')
          : _normalize('http://192.168.11.43:3000'); // your Mac’s LAN when testing on device
    }

    if (Platform.isIOS) {
      // iOS simulator can use localhost
      if (await _isEmulator()) {
        return _normalize('http://localhost:3000');
      } else {
        // Physical iPhone — use your machine's LAN IP
        return _normalize('http://192.168.1.6:3000'); // TODO: change to your machine's LAN IP
      }
    }

    return _normalize('http://127.0.0.1:3000');
  }

  static String _normalize(String base) =>
      base.endsWith('/') ? base.substring(0, base.length - 1) : base;
}
