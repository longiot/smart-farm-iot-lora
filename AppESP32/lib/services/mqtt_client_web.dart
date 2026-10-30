import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient setupMqttClient(String server, String clientId) {
  // Web MUST use WebSockets (MqttBrowserClient)
  // HiveMQ public WebSocket endpoint: ws://broker.hivemq.com:8000/mqtt
  final client = MqttBrowserClient.withPort(
    'ws://broker.hivemq.com/mqtt',
    clientId,
    8000,
  );
  return client;
}
