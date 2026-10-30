import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/schedule_entry.dart';

/// Quản lý lịch hẹn giờ bằng Firebase Firestore và đẩy xuống ESP32 qua MQTT
class ScheduleService extends ChangeNotifier {
  static const int maxSchedules = 5;
  static const String _collection = 'schedules';

  List<ScheduleEntry> _schedules = [];
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Callback để publish MQTT retained message (từ MqttService)
  void Function(String topic, String payload)? _publishRetained;

  List<ScheduleEntry> get schedules => List.unmodifiable(_schedules);

  String? _deviceId;
  StreamSubscription? _sub;

  void setDeviceId(String deviceId) {
    if (_deviceId == deviceId) return;
    _deviceId = deviceId;
    _sub?.cancel();
    _schedules.clear();
    
    _sub = _db.collection('devices').doc(_deviceId).collection('schedules').snapshots().listen((snap) {
      _schedules = snap.docs.map((doc) {
        final d = doc.data();
        return ScheduleEntry.fromJson({
          ...d,
          'id': doc.id,
        });
      }).toList();
      
      syncToMqtt();
      notifyListeners();
    }, onError: (e) {
      debugPrint('[ScheduleService] Firestore listen error: $e');
    });
  }

  Future<void> init() async {
    // Không làm gì ở init nữa vì cần chờ có deviceId
  }

  void setMqttPublisher(void Function(String topic, String payload) publisher) {
    _publishRetained = publisher;
    debugPrint('[ScheduleService] MQTT Publisher được gán.');
  }

  /// Gửi toàn bộ lịch trình dưới dạng một chuỗi tới ESP32
  /// Định dạng ví dụ: pump,08:30,09:00,1|shade,10:00,11:00,0
  void syncToMqtt() {
    if (_publishRetained == null || _deviceId == null) return;
    
    // Gom các lịch đang enabled
    final List<String> parts = [];
    for (final s in _schedules) {
      final onH = s.onTime.hour.toString().padLeft(2, '0');
      final onM = s.onTime.minute.toString().padLeft(2, '0');
      final offH = s.offTime.hour.toString().padLeft(2, '0');
      final offM = s.offTime.minute.toString().padLeft(2, '0');
      final en = s.enabled ? '1' : '0';
      parts.add('${s.deviceId},$onH:$onM,$offH:$offM,$en');
    }

    final payload = parts.join('|');
    _publishRetained!('esp32agri/$_deviceId/schedule', payload);
  }

  Future<void> addSchedule(ScheduleEntry entry) async {
    if (_deviceId == null || _schedules.length >= maxSchedules) return;
    await _db.collection('devices').doc(_deviceId).collection('schedules').doc(entry.id).set(entry.toJson());
  }

  Future<void> removeSchedule(String id) async {
    if (_deviceId == null) return;
    await _db.collection('devices').doc(_deviceId).collection('schedules').doc(id).delete();
  }

  Future<void> toggleSchedule(String id) async {
    if (_deviceId == null) return;
    final idx = _schedules.indexWhere((s) => s.id == id);
    if (idx < 0) return;
    final newValue = !_schedules[idx].enabled;
    await _db.collection('devices').doc(_deviceId).collection('schedules').doc(id).update({'enabled': newValue});
  }

  @override
  void dispose() {
    super.dispose();
  }
}
