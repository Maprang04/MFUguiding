import 'package:flutter/services.dart';

class ConnectedWifiReading {
  final String ssid;
  final String bssid;
  final int rssi;
  final String accessPoint;
  final Map<String, int> accessPointRssi;

  const ConnectedWifiReading({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.accessPoint,
    this.accessPointRssi = const {},
  });
}

class ConnectedWifiException implements Exception {
  final String message;
  const ConnectedWifiException(this.message);
}

class ConnectedWifiService {
  static const _channel = MethodChannel('mfu.smartguide/connected_wifi');
  static const _apByBssidPrefix = <String, String>{
    'f0:1d:2d:ba:38': 'AP1',
    'f0:1d:2d:ba:98': 'AP2',
    'f0:1d:2d:bc:41': 'AP3',
  };

  Future<ConnectedWifiReading> read() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getConnectedWifi',
      );
      final ssid = raw?['ssid']?.toString() ?? '';
      final bssid = (raw?['bssid']?.toString() ?? '').toLowerCase();
      final rssi = (raw?['rssi'] as num?)?.toInt();
      if (ssid != 'AS-Project') {
        throw const ConnectedWifiException(
          'Connect to the AS-Project Wi-Fi network.',
        );
      }
      if (rssi == null || bssid.isEmpty || bssid == '02:00:00:00:00:00') {
        throw const ConnectedWifiException(
          'Enable Wi-Fi and Location to determine the zone.',
        );
      }
      String? ap;
      for (final entry in _apByBssidPrefix.entries) {
        if (bssid.startsWith(entry.key)) {
          ap = entry.value;
        }
      }
      if (ap == null) {
        throw ConnectedWifiException('Unknown AS-Project BSSID: $bssid');
      }
      final scan = await _readAccessPointScan();
      scan[ap] = rssi;
      return ConnectedWifiReading(
        ssid: ssid,
        bssid: bssid,
        rssi: rssi,
        accessPoint: ap,
        accessPointRssi: scan,
      );
    } on PlatformException catch (error) {
      throw ConnectedWifiException(error.message ?? 'Cannot read Wi-Fi data.');
    }
  }

  Future<Map<String, int>> _readAccessPointScan() async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getWifiScan');
      final strongest = <String, int>{};
      for (final item in raw ?? const []) {
        if (item is! Map) continue;
        final bssid = (item['bssid']?.toString() ?? '').toLowerCase();
        final rssi = (item['rssi'] as num?)?.toInt();
        if (rssi == null) continue;
        for (final entry in _apByBssidPrefix.entries) {
          if (bssid.startsWith(entry.key)) {
            final previous = strongest[entry.value];
            if (previous == null || rssi > previous) {
              strongest[entry.value] = rssi;
            }
          }
        }
      }
      return strongest;
    } on PlatformException {
      // Connected-AP positioning remains available when scan is throttled or
      // unavailable on a particular Android device.
      return <String, int>{};
    }
  }
}
