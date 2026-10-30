import 'package:appesp32/models/sensor_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SensorData.fromMqttJson', () {
    test('parses a valid retained MQTT payload', () {
      final data = SensorData.fromMqttJson({
        'ts': '2026-05-31 10:15:00',
        'temp': 30.5,
        'hum': 72,
        'lux': 1240.5,
        'sd': 1,
        'pending': 0,
      });

      expect(data.timestamp, '2026-05-31 10:15:00');
      expect(data.temp, 30.5);
      expect(data.humidity, 72);
      expect(data.light, 1240.5);
      expect(data.sdReady, isTrue);
      expect(data.pendingRows, 0);
      expect(data.tempValid, isTrue);
      expect(data.humValid, isTrue);
      expect(data.lightValid, isTrue);
    });

    test('marks missing sensor values as invalid', () {
      final data = SensorData.fromMqttJson({
        'ts': 'No_Time',
        'sd': 0,
        'pending': 1,
      });

      expect(data.timestamp, 'No_Time');
      expect(data.tempValid, isFalse);
      expect(data.humValid, isFalse);
      expect(data.lightValid, isFalse);
      expect(data.sdReady, isFalse);
      expect(data.pendingRows, 1);
    });
  });
}
