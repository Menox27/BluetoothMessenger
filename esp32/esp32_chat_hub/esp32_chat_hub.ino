#include <WiFi.h>
#include <AsyncTCP.h>
#include <ESPAsyncWebServer.h>
#include <NimBLEDevice.h>
#include <ArduinoJson.h>

static const char* SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
static const char* CMD_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E";
static const char* RESP_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

AsyncWebServer server(80);
AsyncWebSocket ws("/chat");

String ownerName = "ESP32 Relay";
String currentSsid = ownerName;
String currentPassword = "";
bool advertEnabled = true;

NimBLECharacteristic* respChar = nullptr;

void sendBleResponse(JsonDocument& doc) {
  if (!respChar) return;
  String payload;
  serializeJson(doc, payload);
  respChar->setValue((uint8_t*)payload.c_str(), payload.length());
  respChar->notify();
}

void updateAdvertPayload() {
  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  if (!advertEnabled) {
    adv->setManufacturerData("");
    return;
  }
  StaticJsonDocument<64> json;
  json["ssid"] = currentSsid.substring(0, 12);
  json["locked"] = currentPassword.length() >= 8;
  String data;
  serializeJson(json, data);
  adv->setManufacturerData(std::string(data.c_str(), data.length()));
}

void startSoftAp(const String& ssid, const String& password) {
  WiFi.softAPdisconnect(true);
  delay(200);
  WiFi.softAP(ssid.c_str(), password.isEmpty() ? nullptr : password.c_str());
  currentSsid = ssid;
  currentPassword = password;
  updateAdvertPayload();
}

class CommandCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* characteristic) override {
    auto value = characteristic->getValue();
    StaticJsonDocument<256> json;
    if (deserializeJson(json, value)) {
      Serial.println("JSON parse error");
      return;
    }
    const char* op = json["op"] | "";
    if (strcmp(op, "SET_NAME") == 0) {
      ownerName = String((const char*)json["name"]);
      currentSsid = ownerName;
    } else if (strcmp(op, "START_AP") == 0) {
      const char* ssid = json["ssid"] | ownerName.c_str();
      const char* password = json["password"] | "";
      startSoftAp(ssid, password);
      StaticJsonDocument<128> resp;
      resp["ok"] = true;
      resp["ip"] = WiFi.softAPIP().toString();
      sendBleResponse(resp);
    } else if (strcmp(op, "ADVERT_MODE") == 0) {
      advertEnabled = json["on"] | true;
      updateAdvertPayload();
    }
  }
};

void handleWsEvent(AsyncWebSocket* server,
                   AsyncWebSocketClient* client,
                   AwsEventType type,
                   void* arg,
                   uint8_t* data,
                   size_t len) {
  if (type == WS_EVT_DATA) {
    AwsFrameInfo* info = (AwsFrameInfo*)arg;
    if (!info->final || info->opcode != WS_TEXT) return;
    String payload;
    for (size_t i = 0; i < len; i++) {
      payload += (char)data[i];
    }
    StaticJsonDocument<256> json;
    if (deserializeJson(json, payload)) {
      return;
    }
    if (!json.containsKey("sender")) {
      json["sender"] = ownerName;
    }
    if (!json.containsKey("ts")) {
      json["ts"] = (uint32_t)(millis() / 1000);
    }
    if (!json.containsKey("type")) {
      json["type"] = "msg";
    }
    String message;
    serializeJson(json, message);
    ws.textAll(message);
  }
}

void setup() {
  Serial.begin(115200);
  WiFi.mode(WIFI_AP_STA);
  startSoftAp(currentSsid, currentPassword);

  NimBLEDevice::init("ESP32 Relay");
  NimBLEServer* bleServer = NimBLEDevice::createServer();
  NimBLEService* service = bleServer->createService(SERVICE_UUID);

  NimBLECharacteristic* cmdChar = service->createCharacteristic(
      CMD_UUID,
      NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  respChar = service->createCharacteristic(
      RESP_UUID,
      NIMBLE_PROPERTY::NOTIFY);
  cmdChar->setCallbacks(new CommandCallbacks());
  service->start();

  NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  updateAdvertPayload();
  advertising->start();

  ws.onEvent(handleWsEvent);
  server.addHandler(&ws);
  server.begin();

  Serial.println("ESP32 chat hub bereit");
}

void loop() {
  // Async server handles everything
}
