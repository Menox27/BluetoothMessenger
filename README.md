# Bluetooth Messenger

Flutter-App (iOS) + ESP32-Sketch zum Aufbau eines Off-Grid-Kommunikationsnetzes. Die App koppelt iPhones via BLE an einen ESP32, setzt den Gerätenamen, startet bei Bedarf einen SoftAP-Kanal oder tritt über NEHotspotConfigurationManager bei und nutzt WebSockets für Gruppenchats.

## Features
- BLE-Service (UUID 6E400001-…) mit Kommandos `SET_NAME`, `START_AP`, `ADVERT_MODE` (JSON über GATT).
- BLE-Advertising enthält SSID + Passwort-Flag und ersetzt iOS-WLAN-Scans.
- Freundesliste (SharedPreferences) für Schnellverbindungen, Join-Screen mit Tabs „Freunde“ / „Neue Kanäle“.
- Chat-UI mit Avataren, Zeitstempeln, WebSocket-Reconnect (Backoff), Sperre solange keine Verbindung.
- ESP32 SoftAP + AsyncWebSocket Broadcast (`ws://192.168.4.1:8080/chat`).

## Projektstruktur
```
lib/
  main.dart
  ble/
    ble_models.dart
    ble_service.dart
  data/
    friends_repo.dart
    user_settings.dart
  net/
    hotspot_configurator.dart
    ws_client.dart
  screens/
    ble_connect_screen.dart
    name_setup_screen.dart
    home_screen.dart
    join_screen.dart
    chat_screen.dart
  widgets/
    chat_bubble.dart
    create_channel_dialog.dart
assets/icons/
  readme.txt
esp32/
  esp32_chat_hub.ino
```

## iOS-spezifische Hinweise
- Info.plist enthält `NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`, `NSLocalNetworkUsageDescription`, `NSLocationWhenInUseUsageDescription`, `NSBonjourServices`.
- `AppDelegate.swift` registriert einen `MethodChannel` (`app.hotspot/configurator`) und ruft `NEHotspotConfigurationManager` auf.
- Xcode Capabilities: `Hotspot Configuration` (Pflicht) und optional `Access WiFi Information` falls SSID gelesen wird.
- WLAN-Scans sind unter iOS nicht erlaubt → Kanalsuche ausschließlich über BLE-Advertisments des ESP32.

## Flutter Setup
1. Abhängigkeiten installieren
   ```bash
   flutter pub get
   ```
2. Tests laufen lassen
   ```bash
   flutter test
   ```
3. iOS Build (requires macOS)
   ```bash
   flutter build ios --release
   ```

## Deployment
### Variante A – Codemagic / CI
1. Repository verbinden, Apple-Entwicklerkonto + Zertifikate hinterlegen.
2. Workflow: `flutter pub get`, `flutter test`, `flutter build ios --release`.
3. Resultierendes `.ipa` zu App Store Connect hochladen → TestFlight/TestFlight-Links verteilen.

### Variante B – Lokales Mac/Xcode
1. `flutter build ios` oder `open ios/Runner.xcworkspace`.
2. In Xcode Team auswählen (Personal Team → 7 Tage gültige Signierung).
3. Hotspot- und Bluetooth-Capability aktivieren, dann direkt auf ein iPhone deployen.

## ESP32-Sketch flashen
1. Aktuelle ESP32-Arduino-Core + Libraries installieren: `NimBLE-Arduino`, `ESPAsyncWebServer`, `AsyncTCP`, `ArduinoJson`.
2. `esp32/esp32_chat_hub.ino` in Arduino IDE oder PlatformIO öffnen.
3. Board/Port wählen, kompilieren und flashen.
4. Serielle Konsole (115200 Baud) zeigt Statusmeldungen.

## Erste Schritte / Manuelle Tests
1. ESP32 einschalten → BLE-Advertising aktiv.
2. App starten → „ESP32 koppeln“ → Gerät auswählen → Verbinden.
3. Name setzen (`SET_NAME`).
4. **Kanal erstellen**
   - Optional Passwort eingeben → App sendet `START_AP`.
   - Hotspot-Join via `NEHotspotConfigurationManager`.
   - Chat öffnet automatisch, Nachricht senden.
5. **Kanal beitreten**
   - Tab „Neue Kanäle“ zeigt BLE-Advertisments (SSID + Schloss).
   - Bei Bedarf Passwort eingeben, Hotspot joinen, Chat prüfen.
6. **Freunde**
   - Kanal erscheint in der Liste (inkl. Passwort-Flag).
   - One-Tap-Reconnect testen.
7. **WebSocket-Reconnect**
   - ESP32 neu starten → App zeigt Status, verbindet automatisch erneut.

## Automatisierte Tests
- `test/chat_message_test.dart` prüft JSON-Serialisierung der Chat-Nachrichten.
- Erweiterbar um Widget-/Integrationstests (z. B. Mock-WebSockets, FriendRepo).

## Sicherheit & Datenschutz
- Passwörter werden nicht persistiert, nur das Flag `locked`.
- BLE-Kommandos validieren Feldlängen (App-seitig 3–20 Zeichen Name, Passwort ≥8 Zeichen falls gesetzt).
- Hinweis im UI, wenn offene Kanäle genutzt werden.

## Bekannte Einschränkungen
- App kann nur Kanäle sehen, die aktiv BLE-Advertisments senden (kein WLAN-Scan).
- Hotspot-Konfiguration funktioniert nicht im iOS-Simulator.
- WebSocket-IP ist standardmäßig `192.168.4.1`; bei Änderungen im Sketch `ChatScreenArgs.targetIp` anpassen.
