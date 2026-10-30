import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/schedule_entry.dart';
import '../services/mqtt_service.dart';
import '../services/schedule_service.dart';
import '../utils/threshold_manager.dart';
import '../widgets/sensor_card.dart';
import '../widgets/relay_card.dart';

// ─────────────────────────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────────────────────────
const _kGreen  = Color(0xFF16A34A);
const _kGreenD = Color(0xFF166534);
const _kAmber  = Color(0xFFF59E0B);
const _kCard   = Color(0xFFF0FDF4);

// ─────────────────────────────────────────────────────────────────
//  DashboardScreen
// ─────────────────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _dev1Name = ThresholdManager.instance.dev1Name;
  String _dev2Name = ThresholdManager.instance.dev2Name;
  String _dev3Name = ThresholdManager.instance.dev3Name;

  // ── Status helpers ───────────────────────────────────────────
  SensorStatus _tempStatus(double v) {
    final t = ThresholdManager.instance;
    if (v.isNaN) return SensorStatus.error;
    if (v > t.tempHigh) return SensorStatus.critical;
    if (v > t.tempHigh - 3) return SensorStatus.warning;
    if (v < t.tempLow) return SensorStatus.critical;
    return SensorStatus.ok;
  }

  SensorStatus _humStatus(double v) {
    final t = ThresholdManager.instance;
    if (v.isNaN) return SensorStatus.error;
    if (v > t.humHigh || v < t.humLow) return SensorStatus.critical;
    if (v > t.humHigh - 5 || v < t.humLow + 5) return SensorStatus.warning;
    return SensorStatus.ok;
  }

  SensorStatus _lightStatus(double v) {
    final t = ThresholdManager.instance;
    if (v < 0) return SensorStatus.error;
    if (v > t.lightHigh) return SensorStatus.critical;
    if (v < t.lightLow) return SensorStatus.warning;
    return SensorStatus.ok;
  }

  // ── Progress helpers ─────────────────────────────────────────
  double _tempProgress(double v) {
    if (v.isNaN) return 0;
    return (v / 50.0).clamp(0.0, 1.0);
  }

  double _humProgress(double v) {
    if (v.isNaN) return 0;
    return (v / 100.0).clamp(0.0, 1.0);
  }

  double _lightProgress(double v) {
    if (v < 0) return 0;
    return (log(v + 1) / log(100001)).clamp(0.0, 1.0);
  }

  SensorStatus _soilStatus(double v) {
    if (v < 0) return SensorStatus.error;
    final t = ThresholdManager.instance;
    if (v > t.soilHigh) return SensorStatus.critical;
    if (v < t.soilLow) return SensorStatus.warning;
    return SensorStatus.ok;
  }

  double _soilProgress(double v) {
    if (v < 0) return 0;
    return (v / 100.0).clamp(0.0, 1.0);
  }

  // ── Rename dialog ────────────────────────────────────────────
  Future<void> _showRenameDialog({
    required String currentName,
    required ValueChanged<String> onSave,
  }) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đổi tên Thiết bị',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nhập tên mới cho Thiết bị',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLength: 30,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    counterText: '',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _kGreen, width: 1.5),
                    ),
                    hintText: 'Tên Thiết bị',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                  onSubmitted: (val) {
                    final trimmed = val.trim();
                    Navigator.of(ctx).pop(trimmed.isEmpty ? null : trimmed);
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Huỷ',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        final trimmed = controller.text.trim();
                        Navigator.of(ctx).pop(trimmed.isEmpty ? null : trimmed);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        'Lưu',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null && result != currentName) {
      onSave(result);
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<MqttService>(
        builder: (context, mqtt, _) {
          final data  = mqtt.latest;
          final stale = mqtt.isDataStale;

          return RefreshIndicator(
            color: _kGreen,
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // ── Hero Header ────────────────────────────────
                _HeroHeader(
                  isConnected: mqtt.isConnected,
                  isStale: stale,
                  timestamp: data.timestamp,
                  pendingRows: data.pendingRows,
                  sdReady: data.sdReady,
                ),

                // ── Section: Cảm biến ──────────────────────────
                _SectionLabel(label: 'CẢM BIẾN MÔI TRƯỜNG'),
                const SizedBox(height: 4),

                // Horizontal compact sensor row
                                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _CompactSensorCard(
                              label: 'Nhiệt độ',
                              value: data.tempValid ? data.temp.toStringAsFixed(1) : '--',
                              unit: 'C',
                              icon: Icons.thermostat_rounded,
                              status: _tempStatus(data.temp),
                              progress: _tempProgress(data.temp),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactSensorCard(
                              label: 'Độ ẩm',
                              value: data.humValid ? data.humidity.toStringAsFixed(1) : '--',
                              unit: '%',
                              icon: Icons.water_drop_rounded,
                              status: _humStatus(data.humidity),
                              progress: _humProgress(data.humidity),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _CompactSensorCard(
                              label: 'Ánh sáng',
                              value: data.lightValid
                                  ? (data.light >= 1000
                                      ? 'k'
                                      : data.light.toStringAsFixed(0))
                                  : '--',
                              unit: 'lux',
                              icon: Icons.wb_sunny_rounded,
                              status: _lightStatus(data.light),
                              progress: _lightProgress(data.light),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactSensorCard(
                              label: 'Độ ẩm đất',
                              value: data.soilValid ? data.soilMoisture.toStringAsFixed(0) : '--',
                              unit: '%',
                              icon: Icons.grass_rounded,
                              status: _soilStatus(data.soilMoisture),
                              progress: _soilProgress(data.soilMoisture),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

                // â”€â”€ Section: Äiá»u khiá»ƒn â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    _SectionLabel(label: 'ĐIỀU KHIỂN Thiết bị'),

                if (!mqtt.isConnected)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kAmber.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 16, color: _kAmber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mất kết nối MQTT â€” Äiá»u khiá»ƒn khÃ´ng kháº£ dá»¥ng',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFFB45309),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                RelayCard(
                  label: _dev1Name,
                  subtitle: 'Qua LoRa - Node 3 (M1)',
                  isOn: mqtt.dev1On,
                  isConnected: mqtt.isConnected,
                  onToggle: mqtt.toggleDev1,
                  icon: Icons.power_rounded,
                  activeColor: _kGreen,
                  onRename: () => _showRenameDialog(
                    currentName: _dev1Name,
                    onSave: (newName) {
                      setState(() => _dev1Name = newName);
                      ThresholdManager.instance.dev1Name = newName;
                      ThresholdManager.instance.save();
                    },
                  ),
                ),
                RelayCard(
                  label: _dev2Name,
                  subtitle: 'Qua LoRa - Node 3 (M2)',
                  isOn: mqtt.dev2On,
                  isConnected: mqtt.isConnected,
                  onToggle: mqtt.toggleDev2,
                  icon: Icons.power_rounded,
                  activeColor: const Color(0xFF8B5CF6),
                  onRename: () => _showRenameDialog(
                    currentName: _dev2Name,
                    onSave: (newName) {
                      setState(() => _dev2Name = newName);
                      ThresholdManager.instance.dev2Name = newName;
                      ThresholdManager.instance.save();
                    },
                  ),
                ),
                RelayCard(
                  label: _dev3Name,
                  subtitle: 'Qua LoRa - Node 3 (M3)',
                  isOn: mqtt.dev3On,
                  isConnected: mqtt.isConnected,
                  onToggle: mqtt.toggleDev3,
                  icon: Icons.power_rounded,
                  activeColor: const Color(0xFFF59E0B),
                  onRename: () => _showRenameDialog(
                    currentName: _dev3Name,
                    onSave: (newName) {
                      setState(() => _dev3Name = newName);
                      ThresholdManager.instance.dev3Name = newName;
                      ThresholdManager.instance.save();
                    },
                  ),
                ),


                const SizedBox(height: 8),

                // â”€â”€ Section: Háº¹n giá» â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    _SectionLabel(label: 'HẸN GIỜ TỰ ĐỘNG'),
                _ScheduleSection(mqtt: mqtt),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Hero Header Card
// ─────────────────────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final bool isConnected;
  final bool isStale;
  final String timestamp;
  final int pendingRows;
  final bool sdReady;

  const _HeroHeader({
    required this.isConnected,
    required this.isStale,
    required this.timestamp,
    required this.pendingRows,
    required this.sdReady,
  });

  @override
  Widget build(BuildContext context) {
    final online      = isConnected && !isStale;
    final statusColor = online
        ? const Color(0xFF4ADE80)
        : (isConnected ? _kAmber : const Color(0xFFFF7070));
    final statusText  = online
        ? 'Trực tuyến'
        : (isConnected ? 'Dữ liệu cũ' : 'Mất kết nối');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 110,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF166534), Color(0xFF15803D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF166534).withOpacity(0.38),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nông Trại Thông Minh',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Cập nhật: $timestamp',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: statusColor.withOpacity(0.55)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Warning chips row
            if (!sdReady || pendingRows > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (!sdReady)
                    _HeroChip(
                      icon: Icons.sd_card_alert_outlined,
                      label: 'Thẻ SD lỗi',
                      color: const Color(0xFFFF7070),
                    ),
                  if (!sdReady && pendingRows > 0)
                    const SizedBox(width: 8),
                  if (pendingRows > 0)
                    _HeroChip(
                      icon: Icons.cloud_upload_outlined,
                      label: '$pendingRows bản ghi chờ sync',
                      color: _kAmber,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _HeroChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
                fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Compact Sensor Card (for horizontal row)
// ─────────────────────────────────────────────────────────────────
class _CompactSensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final SensorStatus status;
  final double progress;

  const _CompactSensorCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.status,
    required this.progress,
  });

  Color get _statusColor {
    switch (status) {
      case SensorStatus.ok:       return _kGreen;
      case SensorStatus.warning:  return _kAmber;
      case SensorStatus.critical: return const Color(0xFFDC2626);
      case SensorStatus.error:    return const Color(0xFF94A3B8);
    }
  }

  String get _statusLabel {
    switch (status) {
      case SensorStatus.ok:       return 'Tắt';
      case SensorStatus.warning:  return 'Cảnh báo';
      case SensorStatus.critical: return 'Nguy hiểm';
      case SensorStatus.error:    return 'Lỗi';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
          ),
        ],
        border: Border(
          top: BorderSide(color: _statusColor, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + status badge row
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: _statusColor, size: 16),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Value
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: _statusColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Section Label
// ─────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 14,
            decoration: BoxDecoration(
              color: _kGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 1.1,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Schedule Section
// ─────────────────────────────────────────────────────────────────
class _ScheduleSection extends StatelessWidget {
  final MqttService mqtt;
  const _ScheduleSection({required this.mqtt});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScheduleService>(
      builder: (context, service, _) {
        final schedules = service.schedules;
        return Column(
          children: [
            // Danh sách lịch
            ...schedules.map((s) => _ScheduleTile(
                  entry: s,
                  onToggle: () => service.toggleSchedule(s.id),
                  onDelete: () => service.removeSchedule(s.id),
                )),

            // Nút thêm mới
            if (schedules.length < ScheduleService.maxSchedules)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: GestureDetector(
                  onTap: () => _showAddDialog(context, service),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _kGreen.withOpacity(0.35),
                        width: 1.5,
                        strokeAlign: BorderSide.strokeAlignCenter,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_circle_outline_rounded,
                            color: _kGreen, size: 18),
                        const SizedBox(width: 8),
                        Text(
                        'Thêm hẹn giờ',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'ÄÃ£ Ä‘áº¡t tá»‘i Ä‘a ${ScheduleService.maxSchedules} lá»‹ch háº¹n giá»',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.7)),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, ScheduleService service) async {
    String deviceId = 'dev1';
    TimeOfDay onTime  = const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay offTime = const TimeOfDay(hour: 7, minute: 0);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _kGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.schedule_rounded,
                            color: _kGreen, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Thêm hẹn giờ',
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Thiết bị
                  Text('Thiết bị',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _DeviceChip(
                        label: ThresholdManager.instance.dev1Name,
                        icon: Icons.power_rounded,
                        color: _kGreen,
                        selected: deviceId == 'dev1',
                        onTap: () =>
                            setDialogState(() => deviceId = 'dev1'),
                      ),
                      const SizedBox(width: 8),
                      _DeviceChip(
                        label: ThresholdManager.instance.dev2Name,
                        icon: Icons.power_rounded,
                        color: const Color(0xFF8B5CF6),
                        selected: deviceId == 'dev2',
                        onTap: () =>
                            setDialogState(() => deviceId = 'dev2'),
                      ),
                      const SizedBox(width: 8),
                      _DeviceChip(
                        label: ThresholdManager.instance.dev3Name,
                        icon: Icons.power_rounded,
                        color: const Color(0xFFF59E0B),
                        selected: deviceId == 'dev3',
                        onTap: () =>
                            setDialogState(() => deviceId = 'dev3'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Giờ bật
                  Text('Giờ bật',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  _TimePickerTile(
                    time: onTime,
                    color: const Color(0xFF22C55E),
                    icon: Icons.power_settings_new_rounded,
                    onPick: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: onTime);
                      if (t != null) setDialogState(() => onTime = t);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Giờ tắt
                  Text('Giờ tắt',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B))),
                  const SizedBox(height: 8),
                  _TimePickerTile(
                    time: offTime,
                    color: const Color(0xFFEF4444),
                    icon: Icons.power_off_rounded,
                    onPick: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: offTime);
                      if (t != null) setDialogState(() => offTime = t);
                    },
                  ),
                  const SizedBox(height: 24),

                  // Nút
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Huỷ',
                              style: GoogleFonts.inter(
                                  color: const Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            final entry = ScheduleEntry(
                              id: 'sch_${DateTime.now().millisecondsSinceEpoch}',
                              deviceId: deviceId,
                              onTime: onTime,
                              offTime: offTime,
                            );
                            service.addSchedule(entry);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Lưu lịch',
                              style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Schedule Tile
// ─────────────────────────────────────────────────────────────────
class _ScheduleTile extends StatelessWidget {
  final ScheduleEntry entry;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _ScheduleTile({
    required this.entry,
    required this.onToggle,
    required this.onDelete,
  });

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon = Icons.power_rounded;
    String name = entry.deviceName;
    
    if (entry.deviceId == 'dev1') {
        color = _kGreen;
        name = ThresholdManager.instance.dev1Name;
    } else if (entry.deviceId == 'dev2') {
        color = const Color(0xFF8B5CF6);
        name = ThresholdManager.instance.dev2Name;
    } else {
        color = const Color(0xFFF59E0B);
        if (entry.deviceId == 'dev3') name = ThresholdManager.instance.dev3Name;
    }


    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: entry.enabled
            ? Colors.white.withOpacity(0.97)
            : Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.enabled
              ? color.withOpacity(0.3)
              : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.schedule_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 4),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _TimeTag(
                        label: 'Bật',
                        time: _fmt(entry.onTime),
                        color: const Color(0xFF22C55E)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 12, color: Color(0xFFCBD5E1)),
                    const SizedBox(width: 8),
                    _TimeTag(
                        label: 'Tắt',
                        time: _fmt(entry.offTime),
                        color: const Color(0xFFEF4444)),
                  ],
                ),
              ],
            ),
          ),
          // Switch bật/tắt lịch
          Switch(
            value: entry.enabled,
            onChanged: (_) => onToggle(),
            activeColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          // Nút xóa
          GestureDetector(
            onTap: onDelete,
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(Icons.delete_outline_rounded,
                  size: 18, color: const Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  Shared small widgets
// ─────────────────────────────────────────────────────────────────
class _TimeTag extends StatelessWidget {
  final String label;
  final String time;
  final Color color;
  const _TimeTag(
      {required this.label, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500),
        ),
        Text(
          time,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DeviceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _DeviceChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color:
                selected ? color.withOpacity(0.1) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? color.withOpacity(0.4)
                  : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? color : const Color(0xFF94A3B8),
                  size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final TimeOfDay time;
  final Color color;
  final IconData icon;
  final VoidCallback onPick;
  const _TimePickerTile({
    required this.time,
    required this.color,
    required this.icon,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            Text(
              'Nhấn để chọn',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFFCBD5E1)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1), size: 18),
          ],
        ),
      ),
    );
  }
}










