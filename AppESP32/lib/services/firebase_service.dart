import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/sensor_data.dart';

/// FirebaseService: đọc lịch sử từ Firestore. ESP32 là nơi ghi dữ liệu.
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._();
  static FirebaseService get instance => _instance;
  FirebaseService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _deviceId;

  void setDeviceId(String deviceId) {
    _deviceId = deviceId;
  }

  /// Query dữ liệu lịch sử theo khoảng thời gian hoặc ngày cụ thể
  Future<List<SensorData>> fetchHistory({Duration? range, DateTime? date}) async {
    if (_deviceId == null) return [];
    try {
      Query query = _db.collection('devices').doc(_deviceId).collection('sensor_logs');

      if (date != null) {
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay));
      } else if (range != null) {
        final since = DateTime.now().subtract(range);
        query = query.where('createdAt', isGreaterThan: Timestamp.fromDate(since));
      }

      final snap = await query
          .orderBy('createdAt', descending: false)
          .limit(5000) // Tăng limit để load đủ 1 ngày
          .get();

      return snap.docs.map((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return SensorData(
          timestamp: d['ts'] as String? ?? '--',
          temp: (d['temp'] as num?)?.toDouble() ?? double.nan,
          humidity: (d['hum'] as num?)?.toDouble() ?? double.nan,
          light: (d['lux'] as num?)?.toDouble() ?? -1,
          soilMoisture: (d['soil'] as num?)?.toDouble() ?? -1,
          sdReady: d['sd'] == 1,
          pendingRows: (d['pending'] as num?)?.toInt() ?? 0,
          createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
    } catch (e) {
      debugPrint('[FirebaseService] fetchHistory error: $e');
      rethrow;
    }
  }

  /// Stream real-time cập nhật từ Firestore (tối đa 500 bản ghi gần nhất)
  Stream<List<SensorData>> historyStream({required Duration range}) {
    if (_deviceId == null) return const Stream.empty();
    final since = DateTime.now().subtract(range);
    debugPrint('[FirebaseService] historyStream started, since=$since');

    // Dùng query đơn giản (chỉ where, không orderBy) để tránh lỗi missing composite index.
    // Sort client-side sau khi nhận data.
    return _db
        .collection('devices')
        .doc(_deviceId)
        .collection('sensor_logs')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
        .limit(600)
        .snapshots()
        .handleError((e) {
          debugPrint('[FirebaseService] historyStream ERROR: $e');
          // Ném lỗi để StreamSubscription.onError bắt được
          throw e;
        })
        .map((snap) {
          debugPrint('[FirebaseService] historyStream snapshot: ${snap.docs.length} docs');
          final list = snap.docs.map((doc) {
            final d = doc.data();
            return SensorData(
              timestamp: d['ts'] as String? ?? '--',
              temp: (d['temp'] as num?)?.toDouble() ?? double.nan,
              humidity: (d['hum'] as num?)?.toDouble() ?? double.nan,
              light: (d['lux'] as num?)?.toDouble() ?? -1,
          soilMoisture: (d['soil'] as num?)?.toDouble() ?? -1,
              sdReady: d['sd'] == 1,
              pendingRows: (d['pending'] as num?)?.toInt() ?? 0,
              createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
            );
          }).toList();

          // Sort client-side theo createdAt tăng dần
          list.sort((a, b) {
            final ta = a.createdAt;
            final tb = b.createdAt;
            if (ta == null && tb == null) return 0;
            if (ta == null) return -1;
            if (tb == null) return 1;
            return ta.compareTo(tb);
          });

          return list;
        });
  }
}

