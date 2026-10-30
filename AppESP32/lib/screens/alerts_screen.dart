import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/mqtt_service.dart';
import '../models/alert_model.dart';
import '../utils/threshold_manager.dart';
import '../widgets/alert_item.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final List<AlertItem> _alerts = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildAlerts();
  }

  void _rebuildAlerts() {
    final mqtt = context.read<MqttService>();
    final data = mqtt.latest;
    final t = ThresholdManager.instance;
    final now = DateFormat('HH:mm').format(DateTime.now());
    final alerts = <AlertItem>[];

    // 1. MQTT / Dữ liệu cũ
    if (!mqtt.isConnected) {
      alerts.add(AlertItem(
        type: AlertType.wifiOffline,
        severity: AlertSeverity.critical,
        title: 'Mất kết nối MQTT',
        description: 'Không nhận được dữ liệu từ hệ thống.',
        timestamp: now,
      ));
    } else if (mqtt.isDataStale) {
      alerts.add(AlertItem(
        type: AlertType.dataStale,
        severity: AlertSeverity.warning,
        title: 'Dữ liệu cũ hơn 10 phút',
        description: 'ESP32 có thể đang ngoại tuyến.',
        timestamp: now,
      ));
    }

    // 2. SD Card
    if (!data.sdReady) {
      alerts.add(AlertItem(
        type: AlertType.sdError,
        severity: AlertSeverity.critical,
        title: 'Thẻ SD không hoạt động',
        description: 'Không lưu được dữ liệu cục bộ.',
        timestamp: now,
      ));
    }

    // 3. Pending data
    if (data.pendingRows > 0) {
      alerts.add(AlertItem(
        type: AlertType.pendingData,
        severity: AlertSeverity.info,
        title: '${data.pendingRows} bản ghi chờ đồng bộ',
        description: 'Đang chờ mạng để đẩy lên Cloud.',
        timestamp: now,
      ));
    }

    // 4. Sensor errors
    if (!data.tempValid) {
      alerts.add(AlertItem(
        type: AlertType.sensorError,
        severity: AlertSeverity.critical,
        title: 'Cảm biến nhiệt độ lỗi',
        description: 'Không nhận được dữ liệu từ DHT11.',
        timestamp: now,
      ));
    }
    if (!data.lightValid) {
      alerts.add(AlertItem(
        type: AlertType.sensorError,
        severity: AlertSeverity.warning,
        title: 'Cảm biến ánh sáng lỗi',
        description: 'Đang thử khôi phục kết nối I2C.',
        timestamp: now,
      ));
    }

    // 5. Threshold alerts
    if (data.tempValid) {
      if (data.temp > t.tempHigh) {
        alerts.add(AlertItem(
          type: AlertType.tempHigh,
          severity: AlertSeverity.critical,
          title: 'Nhiệt độ quá cao',
          description:
              '${data.temp.toStringAsFixed(1)}°C vượt ngưỡng ${t.tempHigh}°C.',
          timestamp: now,
        ));
      } else if (data.temp < t.tempLow) {
        alerts.add(AlertItem(
          type: AlertType.tempLow,
          severity: AlertSeverity.warning,
          title: 'Nhiệt độ quá thấp',
          description:
              '${data.temp.toStringAsFixed(1)}°C dưới ngưỡng ${t.tempLow}°C.',
          timestamp: now,
        ));
      }
    }

    if (data.humValid) {
      if (data.humidity < t.humLow) {
        alerts.add(AlertItem(
          type: AlertType.humLow,
          severity: AlertSeverity.critical,
          title: 'Độ ẩm thấp - Cần tưới nước',
          description:
              '${data.humidity.toStringAsFixed(0)}% dưới ngưỡng ${t.humLow.toInt()}%.',
          timestamp: now,
        ));
      } else if (data.humidity > t.humHigh) {
        alerts.add(AlertItem(
          type: AlertType.humHigh,
          severity: AlertSeverity.warning,
          title: 'Độ ẩm quá cao',
          description:
              '${data.humidity.toStringAsFixed(0)}% vượt ngưỡng ${t.humHigh.toInt()}%.',
          timestamp: now,
        ));
      }
    }

    if (data.lightValid) {
      if (data.light > t.lightHigh) {
        alerts.add(AlertItem(
          type: AlertType.lightHigh,
          severity: AlertSeverity.warning,
          title: 'Ánh sáng quá mạnh',
          description:
              'Cường độ ${(data.light / 1000).toStringAsFixed(0)}k lux vượt ${(t.lightHigh / 1000).toStringAsFixed(0)}k lux.',
          timestamp: now,
        ));
      }
    }

    if (data.soilValid) {
      if (data.soilMoisture > t.soilHigh) {
        alerts.add(AlertItem(
          type: AlertType.soilHigh, // Warning: we might need to add soilHigh to AlertType if it doesn't exist
          severity: AlertSeverity.critical,
          title: 'Độ ẩm đất quá cao',
          description:
              'Độ ẩm đất hiện tại ${data.soilMoisture.toStringAsFixed(0)}% đã vượt ngưỡng an toàn ${t.soilHigh.toInt()}%.',
          timestamp: now,
        ));
      } else if (data.soilMoisture < t.soilLow) {
        alerts.add(AlertItem(
          type: AlertType.soilLow,
          severity: AlertSeverity.warning,
          title: 'Đất quá khô',
          description:
              'Độ ẩm đất ${data.soilMoisture.toStringAsFixed(0)}% dưới ngưỡng ${t.soilLow.toInt()}%. Hãy bật máy bơm.',
          timestamp: now,
        ));
      }
    }

    setState(() {
      _alerts
        ..clear()
        ..addAll(alerts);
    });
  }

  void _dismiss(int index) {
    setState(() {
      _alerts[index] = _alerts[index].copyWith(isResolved: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final activeAlerts = _alerts.where((a) => !a.isResolved).length;

    return Consumer<MqttService>(
      builder: (context, mqtt, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAlerts());

        return SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // ── Header Summary ──
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: activeAlerts > 0
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                    width: 4,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activeAlerts > 0
                          ? const Color(0xFFDC2626).withOpacity(0.12)
                          : const Color(0xFF16A34A).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      activeAlerts > 0
                          ? Icons.notifications_active_rounded
                          : Icons.check_circle_rounded,
                      color: activeAlerts > 0
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeAlerts > 0
                              ? '$activeAlerts vấn đề cần xử lý'
                              : 'Hệ thống hoạt động tốt',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          activeAlerts > 0
                              ? 'Hãy kiểm tra các thiết bị ngay'
                              : 'Không có cảnh báo mới nào',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _rebuildAlerts,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.refresh_rounded,
                            size: 18, color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Alert List ──
            Expanded(
              child: _alerts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.done_all_rounded,
                                size: 48, color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Không có cảnh báo nào',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: _alerts.length,
                      itemBuilder: (context, i) {
                        return AlertItemWidget(
                          alert: _alerts[i],
                          onDismiss: _alerts[i].isResolved
                              ? null
                              : () => _dismiss(i),
                        );
                      },
                    ),
            ),
          ],
        ));
      },
    );
  }
}
