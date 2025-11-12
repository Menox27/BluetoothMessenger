import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _channelName = 'app.hotspot/configurator';

final hotspotConfiguratorProvider =
    Provider<HotspotConfigurator>((_) => HotspotConfigurator());

class HotspotConfigurator {
  static const _channel = MethodChannel(_channelName);

  Future<void> join({
    required String ssid,
    String? password,
  }) async {
    if (!Platform.isIOS) {
      throw UnsupportedError('Hotspot-Konfiguration nur auf iOS verfügbar');
    }
    await _channel.invokeMethod('joinChannel', {
      'ssid': ssid,
      'password': password,
    });
  }
}
