import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum SensorStatus { ok, warning, critical, error }

class SensorCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final SensorStatus status;
  final double progress; // 0.0 – 1.0
  final IconData icon;

  const SensorCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.progress,
    required this.icon,
  });

  Color get _statusColor {
    switch (status) {
      case SensorStatus.ok:       return const Color(0xFF16A34A);
      case SensorStatus.warning:  return const Color(0xFFF59E0B);
      case SensorStatus.critical: return const Color(0xFFDC2626);
      case SensorStatus.error:    return const Color(0xFF94A3B8);
    }
  }

  Color get _iconBgColor {
    switch (status) {
      case SensorStatus.ok:       return const Color(0xFFDCFCE7);
      case SensorStatus.warning:  return const Color(0xFFFEF3C7);
      case SensorStatus.critical: return const Color(0xFFFEE2E2);
      case SensorStatus.error:    return const Color(0xFFF1F5F9);
    }
  }

  String get _statusLabel {
    switch (status) {
      case SensorStatus.ok:       return 'Tốt';
      case SensorStatus.warning:  return 'Cảnh báo';
      case SensorStatus.critical: return 'Nguy hiểm';
      case SensorStatus.error:    return 'Lỗi';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border(
          left: BorderSide(color: _statusColor, width: 3.5),
        ),
      ),
      child: Row(
        children: [
          // Icon vòng tròn màu
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          // Giá trị chính
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      unit,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar đẹp
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: _statusColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Badge trạng thái
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _statusColor.withOpacity(0.3)),
                ),
                child: Text(
                  _statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
