import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter/foundation.dart';

typedef MQTTMessageHandler = void Function(String topic, String message);
typedef MQTTDisconnectHandler = void Function();

class MQTTServices {
  static MqttServerClient? _client;

  static bool _isConnecting = false;
  static bool _isConnected = false;
  static bool _hasConnected = false;

  static MQTTMessageHandler? _onMessage;
  static MQTTDisconnectHandler? _onDisconnected;
  static VoidCallback? _onConnected;

static Future<void> connect() async {
  if (_isConnected || _isConnecting) return;
  _isConnecting = true;

  final clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
  _client = MqttServerClient('broker.hivemq.com', clientId);

  _client!
    ..port = 1883
    ..keepAlivePeriod = 30
    ..setProtocolV311()
    ..connectTimeoutPeriod = 60000
    ..logging(on: true)
    ..onDisconnected = _internalOnDisconnected;

  final connMessage = MqttConnectMessage()
      .withClientIdentifier(clientId)
      .startClean()
      .withWillQos(MqttQos.atMostOnce);

  _client!.connectionMessage = connMessage;

  try {
    final status = await _client!.connect();
    if (status?.state == MqttConnectionState.connected) {
      debugPrint('✅ MQTT Connected');
      _isConnected = true;
      _hasConnected = true;
      _onConnected?.call();

      _client!.updates?.listen((messages) {
        final recMess = messages[0].payload as MqttPublishMessage;
        final payload = MqttPublishPayload.bytesToStringAsString(
            recMess.payload.message);

        final topic = messages[0].topic;
        _onMessage?.call(topic, payload);
      });
    } else {
      debugPrint('❌ MQTT connection failed: ${status?.state}');
      _client!.disconnect();
    }
  } catch (e) {
    debugPrint('❌ MQTT Exception: $e');
    _client!.disconnect();
  } finally {
    _isConnecting = false;
  }
}

  static void _internalOnDisconnected() {
    _isConnected = false;
    debugPrint('⚠️ MQTT Disconnected');
    _onDisconnected?.call();
  }

  static void setMessageHandler(MQTTMessageHandler handler) {
    _onMessage = handler;
  }

  static void setOnDisconnected(MQTTDisconnectHandler handler) {
    _onDisconnected = handler;
  }

  static void setOnConnected(VoidCallback handler) {
    _onConnected = handler;
    if (_isConnected && _hasConnected) {
      _onConnected?.call();
    }
  }

  static void subscribe(String topic) {
    if (_isConnected && _client != null) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
      debugPrint("📡 Subscribed to $topic");
    }
  }

  static Future<void> publishMessage(String topic, String message) async {
    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint("📤 Published $message to $topic");
    } else {
      debugPrint("❌ MQTT not connected, message not sent");
    }
  }
}
