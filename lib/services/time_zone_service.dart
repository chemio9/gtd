import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

/// Resolves the device IANA timezone name for calendar sync.
///
/// Wrapped in a seam (and a timeout) because the platform lookup is a plugin
/// call that must never block a sync.
class TimeZoneService {
  const TimeZoneService();

  Future<String> localZoneName() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone().timeout(
        const Duration(seconds: 2),
      );
      return info.identifier;
    } on Object {
      return 'UTC';
    }
  }
}

final timeZoneServiceProvider = Provider<TimeZoneService>(
  (ref) => const TimeZoneService(),
);
