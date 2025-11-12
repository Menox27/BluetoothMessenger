import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../data/friends_repo.dart';
import '../data/user_settings.dart';
import '../net/hotspot_configurator.dart';
import '../widgets/create_channel_dialog.dart';
import 'chat_screen.dart';
import 'join_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerAsync = ref.watch(ownerNameProvider);
    final connectionAsync = ref.watch(bleConnectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hauptmenü'),
        actions: [
          IconButton(
            onPressed: () => ref.read(bleServiceProvider).disconnect(),
            icon: const Icon(Icons.bluetooth_disabled),
            tooltip: 'Trennen',
          ),
        ],
      ),
      body: ownerAsync.when(
        data: (owner) {
          if (owner == null) {
            return const Center(child: Text('Kein Name gespeichert.'));
          }
          final connectedName =
              connectionAsync.value?.device?.name ?? 'unbekannt';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(owner),
                  subtitle: Text('Verbunden mit $connectedName'),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () =>
                    _handleCreateChannel(context, ref, owner),
                icon: const Icon(Icons.wifi),
                label: const Text('Kanal erstellen'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, JoinScreen.routeName),
                icon: const Icon(Icons.group),
                label: const Text('Mit Kanal verbinden'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Fehler: $error')),
      ),
    );
  }

  Future<void> _handleCreateChannel(
    BuildContext context,
    WidgetRef ref,
    String ownerName,
  ) async {
    final result = await showCreateChannelDialog(context);
    if (result == null) return;
    try {
      final ip = await ref.read(bleServiceProvider).startSoftAp(
            ssid: ownerName,
            password: result.password,
          );
      await ref.read(bleServiceProvider).setAdvertMode(result.advertise);
      await ref.read(hotspotConfiguratorProvider).join(
            ssid: ownerName,
            password: result.password,
          );
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await ref.read(friendsNotifierProvider.notifier).upsert(
            FriendChannel(
              ssid: ownerName,
              locked: (result.password ?? '').isNotEmpty,
              lastUsedEpoch: now,
              nickname: ownerName,
            ),
          );
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          ChatScreen.routeName,
          arguments: ChatScreenArgs(
            ssid: ownerName,
            username: ownerName,
            targetIp: ip,
          ),
        );
      }
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $err')),
      );
    }
  }
}
