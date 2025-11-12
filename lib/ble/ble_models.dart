import 'package:flutter_blue_plus/flutter_blue_plus.dart';

const kBleServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
const kBleCmdCharacteristicUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
const kBleRespCharacteristicUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

enum BleLinkStatus { idle, scanning, connecting, connected, error }

class BleDeviceSummary {
  BleDeviceSummary({
    required this.device,
    required this.name,
    required this.id,
    required this.rssi,
    required this.connectable,
  });

  final BluetoothDevice device;
  final String name;
  final String id;
  final int rssi;
  final bool connectable;
}

class BleAdvertisedChannel {
  BleAdvertisedChannel({
    required this.device,
    required this.deviceId,
    required this.ssid,
    required this.locked,
    required this.rssi,
  });

  final BluetoothDevice device;
  final String deviceId;
  final String ssid;
  final bool locked;
  final int rssi;
}

class BleConnectionState {
  BleConnectionState._(this.status, this.device, this.message);

  factory BleConnectionState.idle() =>
      BleConnectionState._(BleLinkStatus.idle, null, null);

  factory BleConnectionState.scanning() =>
      BleConnectionState._(BleLinkStatus.scanning, null, null);

  factory BleConnectionState.connecting(BleDeviceSummary device) =>
      BleConnectionState._(BleLinkStatus.connecting, device, null);

  factory BleConnectionState.connected(BleDeviceSummary device) =>
      BleConnectionState._(BleLinkStatus.connected, device, null);

  factory BleConnectionState.error(String message) =>
      BleConnectionState._(BleLinkStatus.error, null, message);

  final BleLinkStatus status;
  final BleDeviceSummary? device;
  final String? message;
}
