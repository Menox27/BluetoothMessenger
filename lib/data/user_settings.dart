import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ownerKey = 'owner_name';

final ownerNameProvider =
    StateNotifierProvider<OwnerNameNotifier, AsyncValue<String?>>((ref) {
  final notifier = OwnerNameNotifier();
  return notifier;
});

class OwnerNameNotifier extends StateNotifier<AsyncValue<String?>> {
  OwnerNameNotifier() : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AsyncValue.data(prefs.getString(_ownerKey));
    } catch (err, st) {
      state = AsyncValue.error(err, st);
    }
  }

  Future<void> save(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerKey, value);
    state = AsyncValue.data(value);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ownerKey);
    state = const AsyncValue.data(null);
  }
}
