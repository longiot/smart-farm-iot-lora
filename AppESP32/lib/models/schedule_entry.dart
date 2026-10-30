import 'package:flutter/material.dart';

/// Model lưu một lịch hẹn giờ cho thiết bị
class ScheduleEntry {
  final String id;
  final String deviceId; // 'pump' hoặc 'shade'
  final TimeOfDay onTime;
  final TimeOfDay offTime;
  bool enabled;

  ScheduleEntry({
    required this.id,
    required this.deviceId,
    required this.onTime,
    required this.offTime,
    this.enabled = true,
  });

  String get deviceName => deviceId == 'pump' ? 'Máy bơm nước' : 'Mái che';

  Map<String, dynamic> toJson() => {
        'id': id,
        'deviceId': deviceId,
        'onHour': onTime.hour,
        'onMinute': onTime.minute,
        'offHour': offTime.hour,
        'offMinute': offTime.minute,
        'enabled': enabled,
      };

  factory ScheduleEntry.fromJson(Map<String, dynamic> j) => ScheduleEntry(
        id: j['id'] as String,
        deviceId: j['deviceId'] as String,
        onTime: TimeOfDay(
          hour: j['onHour'] as int,
          minute: j['onMinute'] as int,
        ),
        offTime: TimeOfDay(
          hour: j['offHour'] as int,
          minute: j['offMinute'] as int,
        ),
        enabled: j['enabled'] as bool? ?? true,
      );
}
