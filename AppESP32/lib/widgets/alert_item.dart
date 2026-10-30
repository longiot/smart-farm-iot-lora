import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/alert_model.dart';

class AlertItemWidget extends StatelessWidget {
  final AlertItem alert;
  final VoidCallback? onDismiss;

  const AlertItemWidget({super.key, required this.alert, this.onDismiss});

  Color get _accentColor {
    if (alert.isResolved) return const Color(0xFF16A34A);
    switch (alert.severity) {
      case AlertSeverity.critical: return const Color(0xFFDC2626);
      case AlertSeverity.warning:  return const Color(0xFFF59E0B);
      case AlertSeverity.info:     return const Color(0xFF3B82F6);
      case AlertSeverity.resolved: return const Color(0xFF16A34A);
    }
  }

  IconData get _alertIcon {
    if (alert.isResolved) return Icons.check_circle_rounded;
    switch (alert.severity) {
      case AlertSeverity.critical: return Icons.error_rounded;
      case AlertSeverity.warning:  return Icons.warning_amber_rounded;
      case AlertSeverity.info:     return Icons.info_rounded;
      case AlertSeverity.resolved: return Icons.check_circle_rounded;
    }
  }

  String get _severityLabel {
    if (alert.isResolved) return 'Đã xử lý';
    switch (alert.severity) {
      case AlertSeverity.critical: return 'NGHIÊM TRỌNG';
      case AlertSeverity.warning:  return 'CẢNH BÁO';
      case AlertSeverity.info:     return 'THÔNG TIN';
      case AlertSeverity.resolved: return 'ĐÃ XỬ LÝ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: alert.isResolved ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(18),
          border: Border(
            left: BorderSide(color: _accentColor, width: 4),
          ),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withOpacity(0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon tròn màu
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_alertIcon, color: _accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge severity
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _accentColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _severityLabel,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: _accentColor,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      alert.title,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: alert.isResolved
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF0F172A),
                        decoration: alert.isResolved
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (alert.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        alert.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 11, color: Color(0xFFCBD5E1)),
                        const SizedBox(width: 4),
                        Text(
                          alert.timestamp,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        if (alert.location.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.location_on_rounded,
                              size: 11, color: Color(0xFFCBD5E1)),
                          const SizedBox(width: 3),
                          Text(
                            alert.location,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (onDismiss != null && !alert.isResolved)
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        size: 14, color: Color(0xFF94A3B8)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
