import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ble/ble_models.dart';
import '../ble/ble_service.dart';
import '../data/user_settings.dart';
import 'name_setup_screen.dart';

class BleConnectScreen extends ConsumerStatefulWidget {
  const BleConnectScreen({super.key});

  static const routeName = '/connect';

  @override
  ConsumerState<BleConnectScreen> createState() => _BleConnectScreenState();
}

class _BleConnectScreenState extends ConsumerState<BleConnectScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions().then((_) =>
        ref.read(bleServiceProvider).startScan());
    ref.listen<AsyncValue<BleConnectionState>>(bleConnectionProvider,
        (previous, next) {
      final state = next.value;
      if (state == null || !mounted) return;
      if (state.status == BleLinkStatus.connected) {
        Navigator.pushReplacementNamed(
            context, NameSetupScreen.routeName);
      } else if (state.status == BleLinkStatus.error &&
          state.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message!)),
        );
      }
    });
  }

  Future<void> _requestPermissions() async {
    final permissions = <Permission>[
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
    final results = await permissions.request();
    final denied =
        results.entries.where((entry) => entry.value.isDenied).toList();
    if (denied.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth-Berechtigungen benötigt.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanAsync = ref.watch(bleScanProvider);
    final statusAsync = ref.watch(bleConnectionProvider);
    final ownerAsync = ref.watch(ownerNameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 koppeln'),
        actions: [
          IconButton(
            onPressed: () => ref.read(bleServiceProvider).startScan(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: scanAsync.when(
        data: (devices) => ListView.builder(
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            return ListTile(
              title: Text(device.name),
              subtitle: Text('${device.id} · RSSI ${device.rssi} dBm'),
              trailing: ElevatedButton(
                onPressed: () => _connect(device),
                child: const Text('Verbinden'),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Scan fehlgeschlagen: $error')),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: statusAsync.when(
          data: (state) {
            final owner = ownerAsync.value;
            final label = switch (state.status) {
              BleLinkStatus.scanning => 'Scanning…',
              BleLinkStatus.connecting =>
                  'Verbinde ${state.device?.name ?? ''}',
              BleLinkStatus.connected =>
                  'Verbunden mit ${state.device?.name ?? ''}' +
                      (owner != null ? ' als $owner' : ''),
              BleLinkStatus.error => 'Fehler: ${state.message ?? ''}',
              _ => 'Bereit',
            };
            return Text(label, textAlign: TextAlign.center);
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> _connect(BleDeviceSummary device) async {
    try {
      await ref.read(bleServiceProvider).connect(device);
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BLE-Fehler: $err')),
      );
    }
  }
}
