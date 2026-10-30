class SensorData {
  final String timestamp;
  final double temp;
  final double humidity;
  final double light;
  final double soilMoisture;
  final bool sdReady;
  final bool online;
  final int pendingRows;
  final DateTime? createdAt; // dùng cho biểu đồ X-axis

  const SensorData({
    required this.timestamp,
    required this.temp,
    required this.humidity,
    required this.light,
    required this.soilMoisture,
    this.sdReady = true,
    this.online = true,
    this.pendingRows = 0,
    this.createdAt,
  });

  factory SensorData.empty() => SensorData(
        timestamp: '--',
        temp: double.nan,
        humidity: double.nan,
        light: -1,
        soilMoisture: -1,
        createdAt: null,
      );

  factory SensorData.fromMqttJson(Map<String, dynamic> json) {
    return SensorData(
      timestamp: json['ts'] ?? '--',
      temp: (json['temp'] as num?)?.toDouble() ?? double.nan,
      humidity: (json['hum'] as num?)?.toDouble() ?? double.nan,
      light: (json['lux'] as num?)?.toDouble() ?? -1,
      soilMoisture: (json['soil'] as num?)?.toDouble() ?? -1,
      sdReady: json['sd'] == 1,
      online: true,
      pendingRows: (json['pending'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.now(),
    );
  }

  factory SensorData.fromFirebaseJson(String ts, Map<dynamic, dynamic> json) {
    return SensorData(
      timestamp: ts,
      temp: (json['temp'] as num?)?.toDouble() ?? double.nan,
      humidity: (json['humidity'] as num?)?.toDouble() ?? double.nan,
      light: (json['light'] as num?)?.toDouble() ?? -1,
      soilMoisture: (json['soil_moisture'] as num?)?.toDouble() ?? -1,
    );
  }

  bool get tempValid => !temp.isNaN;
  bool get humValid => !humidity.isNaN;
  bool get lightValid => light >= 0;
  bool get soilValid => soilMoisture >= 0;
}

