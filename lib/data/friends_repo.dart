import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _friendsKey = 'saved_channels';

class FriendChannel {
  FriendChannel({
    required this.ssid,
    required this.locked,
    required this.lastUsedEpoch,
    this.nickname,
  });

  final String ssid;
  final bool locked;
  final int lastUsedEpoch;
  final String? nickname;

  FriendChannel copyWith({
    String? ssid,
    bool? locked,
    int? lastUsedEpoch,
    String? nickname,
  }) {
    return FriendChannel(
      ssid: ssid ?? this.ssid,
      locked: locked ?? this.locked,
      lastUsedEpoch: lastUsedEpoch ?? this.lastUsedEpoch,
      nickname: nickname ?? this.nickname,
    );
  }

  Map<String, dynamic> toJson() => {
        'ssid': ssid,
        'locked': locked,
        'lastUsed': lastUsedEpoch,
        'nickname': nickname,
      };

  static FriendChannel fromJson(Map<String, dynamic> json) {
    return FriendChannel(
      ssid: json['ssid'] as String,
      locked: json['locked'] as bool? ?? false,
      lastUsedEpoch: json['lastUsed'] as int? ?? 0,
      nickname: json['nickname'] as String?,
    );
  }
}

class FriendsRepository {
  Future<List<FriendChannel>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_friendsKey) ?? <String>[];
    final parsed = raw
        .map((entry) =>
            FriendChannel.fromJson(jsonDecode(entry) as Map<String, dynamic>))
        .toList();
    parsed.sort((a, b) => b.lastUsedEpoch.compareTo(a.lastUsedEpoch));
    return parsed;
  }

  Future<void> save(List<FriendChannel> friends) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = friends.map((f) => jsonEncode(f.toJson())).toList();
    await prefs.setStringList(_friendsKey, payload);
  }
}

final friendsRepositoryProvider =
    Provider<FriendsRepository>((_) => FriendsRepository());

final friendsNotifierProvider =
    StateNotifierProvider<FriendsNotifier, AsyncValue<List<FriendChannel>>>(
        (ref) {
  final repo = ref.watch(friendsRepositoryProvider);
  return FriendsNotifier(repo);
});

class FriendsNotifier extends StateNotifier<AsyncValue<List<FriendChannel>>> {
  FriendsNotifier(this._repo) : super(const AsyncValue.loading()) {
    _refresh();
  }

  final FriendsRepository _repo;

  Future<void> _refresh() async {
    try {
      final entries = await _repo.load();
      state = AsyncValue.data(entries);
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  Future<void> upsert(FriendChannel friend) async {
    final current = [...state.value ?? <FriendChannel>[]];
    current.removeWhere((f) => f.ssid == friend.ssid);
    current.add(friend);
    current.sort((a, b) => b.lastUsedEpoch.compareTo(a.lastUsedEpoch));
    state = AsyncValue.data(current);
    await _repo.save(current);
  }

  Future<void> remove(String ssid) async {
    final current = [...state.value ?? <FriendChannel>[]];
    current.removeWhere((f) => f.ssid == ssid);
    state = AsyncValue.data(current);
    await _repo.save(current);
  }
}
