// lib/services/timezone_helper.dart
import 'package:flutter/services.dart';

class TimezoneHelper {
  static const _ch = MethodChannel('app.timezone/channel');

  static Future<String> getLocalTimezone() async {
    try {
      final tz = await _ch.invokeMethod<String>('getLocalTimezone');
      return tz ?? 'UTC';
    } catch (_) {
      return 'UTC';
    }
  }
}
