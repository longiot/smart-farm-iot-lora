import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'mqtt_client_stub.dart'
    if (dart.library.html) 'mqtt_client_web.dart'
    if (dart.library.io) 'mqtt_client_native.dart';
import '../models/sensor_data.dart';

class MqttService extends ChangeNotifier {
  // HiveMQ public broker (free, reliable, no signup)
  static const String _brokerHost  = 'broker.hivemq.com';

  String? _deviceId;

  void setDeviceId(String deviceId) {
    if (_deviceId == deviceId) return;
    _deviceId = deviceId;
    if (_isConnected) {
      _client?.disconnect();
    } else {
      connect();
    }
  }

  // Topics — động theo deviceId
  String get topicSensorData => 'esp32agri/$_deviceId/sensor/data';
  String get topicStatus     => 'esp32agri/$_deviceId/status';
  String get topicControlDev1 => 'esp32agri/$_deviceId/control/dev1';
  String get topicControlDev2 => 'esp32agri/$_deviceId/control/dev2';
  String get topicControlDev3 => 'esp32agri/$_deviceId/control/dev3';

  // Generate unique client ID to avoid conflict on public broker
  static String get _clientId =>
      'esp32app_${DateTime.now().millisecondsSinceEpoch}';

  MqttClient? _client;
  SensorData _latest = SensorData.empty();
  bool _isConnected = false;
  bool _dev1On = false;
  bool _dev2On = false;
  bool _dev3On = false;
  DateTime? _lastReceived;
  bool _connecting  = false;
  Timer? _retryTimer;

  // Lưu 50 điểm data gần nhất để vẽ biểu đồ
  final List<SensorData> _history = [];
  static const int _maxHistory = 50;

  final StreamController<SensorData> _dataController =
      StreamController<SensorData>.broadcast();

  SensorData get latest        => _latest;
  bool get isConnected         => _isConnected;
  bool get dev1On => _dev1On;
  bool get dev2On => _dev2On;
  bool get dev3On => _dev3On;
  List<SensorData> get history => List.unmodifiable(_history);
  Stream<SensorData> get dataStream => _dataController.stream;

  bool get isDataStale {
    if (_lastReceived == null) return true;
    return DateTime.now().difference(_lastReceived!).inSeconds > 600; // 10 phut
  }

  Future<void> connect() async {
    if (_deviceId == null || _deviceId!.isEmpty) return;
    if (_connecting || _isConnected) return;
    _connecting = true;

    final id = _clientId;
    debugPrint('[MQTT] Connecting as $id ...');

    try {
      _client = setupMqttClient(_brokerHost, id);

      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.connectTimeoutPeriod = 10000;
      _client!.onDisconnected = _onDisconnected;
      _client!.onConnected    = _onConnected;
      _client!.autoReconnect  = false; // We handle retry manually

      final connMsg = MqttConnectMessage()
          .withClientIdentifier(id)
          .startClean()
          .withWillQos(MqttQos.atMostOnce);
      _client!.connectionMessage = connMsg;

      await _client!.connect();
    } on NoConnectionException catch (e) {
      debugPrint('[MQTT] NoConnectionException: $e');
      _onConnectFailed();
      return;
    } catch (e) {
      debugPrint('[MQTT] Error: $e');
      _onConnectFailed();
      return;
    } finally {
      _connecting = false;
    }

    if (_client?.connectionStatus?.state == MqttConnectionState.connected) {
      // Subscribe topics
      _client!.subscribe(topicSensorData, MqttQos.atLeastOnce);
      _client!.subscribe(topicStatus, MqttQos.atLeastOnce);

      _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
        for (final msg in messages) {
          final payload = (msg.payload as MqttPublishMessage).payload;
          final raw = MqttPublishPayload.bytesToStringAsString(payload.message);
          _handleMessage(msg.topic, raw);
        }
      });
    } else {
      debugPrint('[MQTT] Connected but state is not connected, retrying...');
      _onConnectFailed();
    }
  }

  void _onConnectFailed() {
    _isConnected = false;
    _connecting = false;
    notifyListeners();
    // Retry after 5 seconds
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), connect);
  }

  void _handleMessage(String topic, String raw) {
    debugPrint('[MQTT] $topic → $raw');
    try {
      if (topic == topicSensorData) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _latest = SensorData.fromMqttJson(json);
        _lastReceived = DateTime.now();
        // Thêm vào history local
        _history.add(_latest);
        if (_history.length > _maxHistory) _history.removeAt(0);
        _dataController.add(_latest);
        notifyListeners();
      } else if (topic == topicStatus) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        _dev1On = json['dev1'] == 1;
        _dev2On = json['dev2'] == 1;
        _dev3On = json['dev3'] == 1;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[MQTT] Parse error: $e');
    }
  }

  void _onConnected() {
    debugPrint('[MQTT] ✅ Connected to broker.hivemq.com');
    _isConnected = true;
    _connecting  = false;
    _retryTimer?.cancel();
    notifyListeners();
  }

  void _onDisconnected() {
    debugPrint('[MQTT] ❌ Disconnected');
    _isConnected = false;
    _connecting  = false;
    notifyListeners();
    // Auto retry
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 5), connect);
  }

  void _publish(String topic, String payload) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] Not connected, cannot publish to $topic');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('[MQTT] Published $topic → $payload');
  }

  void publishRetained(String topic, String payload) {
    if (_client?.connectionStatus?.state != MqttConnectionState.connected) {
      debugPrint('[MQTT] Not connected, cannot publish retained to $topic');
      return;
    }
    final builder = MqttClientPayloadBuilder()..addString(payload);
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: true);
    debugPrint('[MQTT] Published Retained $topic → $payload');
  }

  void setDev1(bool on) {
    _dev1On = on;
    _publish(topicControlDev1, on ? 'ON' : 'OFF');
    notifyListeners();
  }

  void setDev2(bool on) {
    _dev2On = on;
    _publish(topicControlDev2, on ? 'ON' : 'OFF');
    notifyListeners();
  }

  void setDev3(bool on) {
    _dev3On = on;
    _publish(topicControlDev3, on ? 'ON' : 'OFF');
    notifyListeners();
  }

  void toggleDev1() => setDev1(!_dev1On);
  void toggleDev2() => setDev2(!_dev2On);
  void toggleDev3() => setDev3(!_dev3On);

  @override
  void dispose() {
    _retryTimer?.cancel();
    _dataController.close();
    _client?.disconnect();
    super.dispose();
  }
}


