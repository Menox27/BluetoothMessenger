import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ble_models.dart';

final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
});

final bleScanProvider = StreamProvider.autoDispose<List<BleDeviceSummary>>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.deviceScanStream;
});

final bleAdvertProvider =
    StreamProvider.autoDispose<List<BleAdvertisedChannel>>((ref) {
  final service = ref.watch(bleServiceProvider);
  return service.advertisementStream;
});

final bleConnectionProvider =
    StreamProvider<BleConnectionState>((ref) async* {
  final service = ref.watch(bleServiceProvider);
  yield* service.connectionStream;
});

class BleService {
  BleService() {
    FlutterBluePlus.setLogLevel(LogLevel.none);
    _connectionController.add(BleConnectionState.idle());
  }

  final _scanController =
      StreamController<List<BleDeviceSummary>>.broadcast();
  final _advertController =
      StreamController<List<BleAdvertisedChannel>>.broadcast();
  final _connectionController =
      StreamController<BleConnectionState>.broadcast();
  final _responseController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<List<BleDeviceSummary>> get deviceScanStream =>
      _scanController.stream;
  Stream<List<BleAdvertisedChannel>> get advertisementStream =>
      _advertController.stream;
  Stream<BleConnectionState> get connectionStream =>
      _connectionController.stream;

  BluetoothDevice? _currentDevice;
  BluetoothCharacteristic? _cmdChar;
  BluetoothCharacteristic? _respChar;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _respSub;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSub;

  final List<BleDeviceSummary> _devices = [];
  final Map<String, BleAdvertisedChannel> _channels = {};

  Future<void> startScan() async {
    _connectionController.add(BleConnectionState.scanning());
    await FlutterBluePlus.stopScan();
    _devices.clear();
    _channels.clear();
    await _scanSub?.cancel();
    await FlutterBluePlus.startScan(
      withServices: [Guid(kBleServiceUuid)],
      androidUsesFineLocation: true,
    );
    _scanSub = FlutterBluePlus.scanResults.listen(_handleScanResults);
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _connectionController.add(BleConnectionState.idle());
  }

  void _handleScanResults(List<ScanResult> results) {
    var devicesUpdated = false;
    for (final result in results) {
      final device = result.device;
      final summary = BleDeviceSummary(
        device: device,
        name: device.platformName.isNotEmpty
            ? device.platformName
            : (result.advertisementData.localName.isNotEmpty
                ? result.advertisementData.localName
                : 'ESP32 Relay'),
        id: device.remoteId.str,
        rssi: result.rssi,
        connectable: result.advertisementData.connectable,
      );

      final index = _devices.indexWhere((d) => d.id == summary.id);
      if (index == -1) {
        _devices.add(summary);
        devicesUpdated = true;
      } else if (_devices[index].rssi != summary.rssi) {
        _devices[index] = summary;
        devicesUpdated = true;
      }

      final advertised = _parseAdvertisement(result);
      if (advertised != null) {
        _channels[advertised.deviceId] = advertised;
        _advertController.add(_channels.values.toList(growable: false));
      }
    }

    if (devicesUpdated) {
      _scanController.add(List.unmodifiable(_devices));
    }
  }

  BleAdvertisedChannel? _parseAdvertisement(ScanResult result) {
    final data = result.advertisementData;
    List<int>? payload;

    if (data.manufacturerData.isNotEmpty) {
      payload = data.manufacturerData.values.first;
    } else if (data.serviceData.isNotEmpty) {
      payload = data.serviceData.values.first;
    }

    if (payload == null || payload.isEmpty) return null;
    try {
      final jsonStr = utf8.decode(payload, allowMalformed: true);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final ssid = (json['ssid'] as String?)?.trim();
      if (ssid == null || ssid.isEmpty) {
        return null;
      }
      return BleAdvertisedChannel(
        device: result.device,
        deviceId: result.device.remoteId.str,
        ssid: ssid,
        locked: json['locked'] as bool? ?? false,
        rssi: result.rssi,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> connect(BleDeviceSummary device) async {
    _connectionController.add(BleConnectionState.connecting(device));
    await _currentDevice?.disconnect();
    _currentDevice = device.device;

    await _deviceStateSub?.cancel();
    _deviceStateSub =
        _currentDevice!.connectionState.listen((connectionState) {
      if (connectionState == BluetoothConnectionState.disconnected) {
        _connectionController.add(BleConnectionState.idle());
      }
    });

    await _currentDevice!.connect(timeout: const Duration(seconds: 15));
    final services = await _currentDevice!.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == Guid(kBleServiceUuid),
      orElse: () => throw Exception('BLE Service nicht gefunden'),
    );

    _cmdChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(kBleCmdCharacteristicUuid),
      orElse: () => throw Exception('CMD Characteristic fehlt'),
    );
    _respChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(kBleRespCharacteristicUuid),
      orElse: () => throw Exception('RESP Characteristic fehlt'),
    );

    await _respChar!.setNotifyValue(true);
    await _respSub?.cancel();
    _respSub = _respChar!.lastValueStream.listen((value) {
      try {
        final map = jsonDecode(utf8.decode(value)) as Map<String, dynamic>;
        _responseController.add(map);
      } catch (_) {}
    });

    _connectionController.add(BleConnectionState.connected(device));
  }

  Future<void> setOwnerName(String name) async {
    await _writeCommand({'op': 'SET_NAME', 'name': name}, false);
  }

  Future<String> startSoftAp({
    required String ssid,
    String? password,
  }) async {
    final response = await _writeCommand(
      {
        'op': 'START_AP',
        'ssid': ssid,
        'password': password ?? '',
      },
      true,
    );
    if (response == null || response['ok'] != true) {
      throw Exception('ESP32 hat START_AP abgelehnt');
    }
    return (response['ip'] as String?) ?? '192.168.4.1';
  }

  Future<void> setAdvertMode(bool on) async {
    await _writeCommand({'op': 'ADVERT_MODE', 'on': on}, false);
  }

  Future<Map<String, dynamic>?> _writeCommand(
    Map<String, dynamic> payload,
    bool expectResponse,
  ) async {
    if (_cmdChar == null) {
      throw Exception('Keine BLE-Verbindung aktiv');
    }
    final bytes = utf8.encode(jsonEncode(payload));
    await _cmdChar!.write(bytes,
        withoutResponse: _cmdChar!.properties.writeWithoutResponse);
    if (!expectResponse) return null;
    return _responseController.stream
        .first
        .timeout(const Duration(seconds: 5));
  }

  Future<void> disconnect() async {
    await _currentDevice?.disconnect();
    _currentDevice = null;
    _cmdChar = null;
    _respChar = null;
    _connectionController.add(BleConnectionState.idle());
  }

  void dispose() {
    _scanSub?.cancel();
    _respSub?.cancel();
    _deviceStateSub?.cancel();
    _scanController.close();
    _advertController.close();
    _connectionController.close();
    _responseController.close();
  }
}
