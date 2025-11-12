import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_models.dart';
import '../ble/ble_service.dart';
import '../data/friends_repo.dart';
import '../data/user_settings.dart';
import '../net/hotspot_configurator.dart';
import 'chat_screen.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key});

  static const routeName = '/join';

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(length: 2, vsync: this);
    ref.read(bleServiceProvider).startScan();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsNotifierProvider);
    final advertsAsync = ref.watch(bleAdvertProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mit Kanal verbinden'),
        bottom: TabBar(
          controller: _controller,
          tabs: const [
            Tab(text: 'Freunde'),
            Tab(text: 'Neue Kanäle'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _controller,
        children: [
          friendsAsync.when(
            data: _buildFriends,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Fehler: $error')),
          ),
          advertsAsync.when(
            data: _buildAdvertisements,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Fehler: $error')),
          ),
        ],
      ),
    );
  }

  Widget _buildFriends(List<FriendChannel> friends) {
    if (friends.isEmpty) {
      return const Center(child: Text('Keine Einträge gespeichert.'));
    }
    return ListView.builder(
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return ListTile(
          title: Text(friend.nickname ?? friend.ssid),
          subtitle: Text(friend.ssid),
          trailing: friend.locked ? const Icon(Icons.lock) : null,
          onTap: () => _joinFriend(friend),
        );
      },
    );
  }

  Widget _buildAdvertisements(List<BleAdvertisedChannel> adverts) {
    if (adverts.isEmpty) {
      return const Center(child: Text('Keine Kanäle gefunden.'));
    }
    return ListView.builder(
      itemCount: adverts.length,
      itemBuilder: (context, index) {
        final advert = adverts[index];
        return ListTile(
          title: Text(advert.ssid),
          subtitle: Text('${advert.deviceId} · RSSI ${advert.rssi} dBm'),
          trailing: advert.locked ? const Icon(Icons.lock) : null,
          onTap: () => _joinAdvert(advert),
        );
      },
    );
  }

  Future<void> _joinFriend(FriendChannel friend) async {
    final password = friend.locked ? await _promptPassword() : null;
    if (friend.locked && (password == null || password.isEmpty)) return;
    await _connectToChannel(friend.ssid, password: password);
  }

  Future<void> _joinAdvert(BleAdvertisedChannel advert) async {
    final password = advert.locked ? await _promptPassword() : null;
    if (advert.locked && (password == null || password.isEmpty)) return;
    await _connectToChannel(advert.ssid, password: password);
  }

  Future<void> _connectToChannel(String ssid, {String? password}) async {
    final ownerName = ref.read(ownerNameProvider).value ?? 'Gast';
    try {
      await ref.read(hotspotConfiguratorProvider).join(
            ssid: ssid,
            password: password,
          );
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await ref.read(friendsNotifierProvider.notifier).upsert(
            FriendChannel(
              ssid: ssid,
              locked: (password ?? '').isNotEmpty,
              lastUsedEpoch: now,
              nickname: ssid,
            ),
          );
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        ChatScreen.routeName,
        arguments: ChatScreenArgs(
          ssid: ssid,
          username: ownerName,
        ),
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Join fehlgeschlagen: $err')),
      );
    }
  }

  Future<String?> _promptPassword() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Passwort erforderlich'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Passwort'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Verbinden'),
          ),
        ],
      ),
    );
  }
}
