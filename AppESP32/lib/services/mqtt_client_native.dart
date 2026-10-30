import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient setupMqttClient(String server, String clientId) {
  // Native (Android/iOS): dùng TCP port 1883
  return MqttServerClient.withPort(server, clientId, 1883);
}
