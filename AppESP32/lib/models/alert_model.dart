enum AlertSeverity { critical, warning, info, resolved }

enum AlertType {
  tempHigh,
  tempLow,
  humHigh,
  humLow,
  lightHigh,
  lightLow,
  soilHigh,
  soilLow,
  sensorError,
  wifiOffline,
  sdError,
  ntpError,
  pendingData,
  dataStale,
}

class AlertItem {
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final String timestamp;
  final String location;
  final bool isResolved;

  const AlertItem({
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    required this.timestamp,
    this.location = 'Nhà kính A1',
    this.isResolved = false,
  });

  AlertItem copyWith({bool? isResolved}) => AlertItem(
        type: type,
        severity: severity,
        title: title,
        description: description,
        timestamp: timestamp,
        location: location,
        isResolved: isResolved ?? this.isResolved,
      );
}
