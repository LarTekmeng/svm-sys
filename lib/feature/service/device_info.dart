import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';

/// Centralized API host resolver for dev/test.
/// Order of precedence:
/// 1) --dart-define=BACKEND_BASE_URL=...
/// 2) Emulator/Simulator conveniences (10.0.2.2 / localhost)
/// 3) Fallback to http://127.0.0.1:3000 (mostly for desktop)
class ApiHost {
  static final String _override =
  const String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');

  static Future<bool> _isEmulator() async {
    final info = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        // Common emulator markers
        final brand = (a.brand ?? '').toLowerCase();
        final model = (a.model ?? '').toLowerCase();
        final product = (a.product ?? '').toLowerCase();
        return brand.contains('google') && (model.contains('sdk') || product.contains('sdk'))
            || model.contains('emulator')
            || product.contains('vbox')
            || product.contains('genymotion');
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        // iOS simulator has "x86_64"/"arm64" with "Simulator" model
        final isSim = (i.isPhysicalDevice == false);
        return isSim;
      }
    } catch (_) {}
    return false;
  }

  static Future<String> resolve() async {
    // 1) Explicit override via --dart-define
    if (_override.isNotEmpty) return _normalize(_override);

    // 2) Platform-based default for dev
    if (kIsWeb) {
      // Use the same origin host (adjust port if needed)
      return _normalize('http://localhost:3000');
    }

    if (Platform.isAndroid) {
      // Android emulator vs physical device
      if (await _isEmulator()) {
        return _normalize('http://10.0.2.2:3000');
      } else {
        // Physical device — EXPECT a dart-define or edit this to your LAN IP when testing.
        // Example: return _normalize('http://192.168.1.50:3000');
        // Keeping a sensible default:
        return _normalize('http://192.168.31.77:3000'); // TODO: change to your machine's LAN IP
      }
    }

    if (Platform.isIOS) {
      // iOS simulator can use localhost
      if (await _isEmulator()) {
        return _normalize('http://localhost:3000');
      } else {
        // Physical iPhone — use your machine's LAN IP
        return _normalize('http://192.168.31.77:3000'); // TODO: change to your machine's LAN IP
      }
    }

    // Desktop dev or other platforms
    return _normalize('http://127.0.0.1:3000');
  }

  static String _normalize(String base) {
    // Drop trailing slash for consistent concatenation
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }
}
