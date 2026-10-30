import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/threshold_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _tempHigh;
  late double _tempLow;
  late double _humHigh;
  late double _humLow;
    late double _lightHigh;
  late double _lightLow;
  late double _soilHigh;
  late double _soilLow;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final t = ThresholdManager.instance;
    _tempHigh  = t.tempHigh;
    _tempLow   = t.tempLow;
    _humHigh   = t.humHigh;
    _humLow    = t.humLow;
        _lightHigh = t.lightHigh;
    _lightLow  = t.lightLow;
    _soilHigh  = t.soilHigh;
    _soilLow   = t.soilLow;
  }

  Future<void> _save() async {
    final t = ThresholdManager.instance;
    t.tempHigh  = _tempHigh;
    t.tempLow   = _tempLow;
    t.humHigh   = _humHigh;
    t.humLow    = _humLow;
        t.lightHigh = _lightHigh;
    t.lightLow  = _lightLow;
    t.soilHigh  = _soilHigh;
    t.soilLow   = _soilLow;
    await t.save();
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  void _changePasswordDialog() {
    final controller = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('Đổi Mật Khẩu', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mật khẩu mới (ít nhất 6 ký tự)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (controller.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Mật khẩu phải từ 6 ký tự trở lên!')),
                        );
                        return;
                      }
                      setStateDialog(() => isLoading = true);
                      try {
                        await FirebaseAuth.instance.currentUser?.updatePassword(controller.text);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đổi mật khẩu thành công!'), backgroundColor: Colors.green),
                          );
                        }
                      } catch (e) {
                        setStateDialog(() => isLoading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Thất bại. Vui lòng đăng xuất và đăng nhập lại trước khi đổi mật khẩu mới.'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Cập nhật', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // ── Hero save button ──
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _saved
                    ? [const Color(0xFF16A34A), const Color(0xFF15803D)]
                    : [const Color(0xFF1E3A1E), const Color(0xFF166534)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _saved ? Icons.check_circle_rounded : Icons.save_rounded,
                          key: ValueKey(_saved),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _saved ? 'Đã lưu thành công!' : 'Lưu cấu hình',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ── Nhiệt độ ──
        _SectionHeader(
          title: 'NHIỆT ĐỘ',
          subtitle: 'Qua LoRa',
          icon: Icons.thermostat_rounded,
          color: const Color(0xFFDC2626),
        ),
        _ThresholdTile(
          label: 'Cảnh báo cao',
          value: _tempHigh,
          unit: '°C',
          min: 20,
          max: 50,
          divisions: 30,
          color: const Color(0xFFDC2626),
          icon: Icons.arrow_upward_rounded,
          onChanged: (v) => setState(() => _tempHigh = v),
        ),
        _ThresholdTile(
          label: 'Cảnh báo thấp',
          value: _tempLow,
          unit: '°C',
          min: 0,
          max: 30,
          divisions: 30,
          color: const Color(0xFF3B82F6),
          icon: Icons.arrow_downward_rounded,
          onChanged: (v) => setState(() => _tempLow = v),
        ),

        const SizedBox(height: 8),

        // ── Độ ẩm ──
        _SectionHeader(
          title: 'ĐỘ ẨM',
          subtitle: 'Qua LoRa',
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF0284C7),
        ),
        _ThresholdTile(
          label: 'Cảnh báo cao',
          value: _humHigh,
          unit: '%',
          min: 50,
          max: 100,
          divisions: 50,
          color: const Color(0xFFDC2626),
          icon: Icons.arrow_upward_rounded,
          onChanged: (v) => setState(() => _humHigh = v),
        ),
        _ThresholdTile(
          label: 'Cảnh báo thấp',
          value: _humLow,
          unit: '%',
          min: 0,
          max: 60,
          divisions: 60,
          color: const Color(0xFF3B82F6),
          icon: Icons.arrow_downward_rounded,
          onChanged: (v) => setState(() => _humLow = v),
        ),

        const SizedBox(height: 8),

        // ── Ánh sáng ──
        _SectionHeader(
          title: 'ÁNH SÁNG',
          subtitle: 'Qua LoRa',
          icon: Icons.wb_sunny_rounded,
          color: const Color(0xFFF59E0B),
        ),
        _ThresholdTile(
          label: 'Quá mạnh',
          value: _lightHigh,
          unit: 'lux',
          min: 10000,
          max: 100000,
          divisions: 90,
          color: const Color(0xFFF59E0B),
          icon: Icons.arrow_upward_rounded,
          onChanged: (v) => setState(() => _lightHigh = v),
          displayFormat: (v) => '${(v / 1000).toStringAsFixed(0)}k',
        ),
        _ThresholdTile(
          label: 'Quá yếu',
          value: _lightLow,
          unit: 'lux',
          min: 0,
          max: 10000,
          divisions: 100,
          color: const Color(0xFF7C3AED),
          icon: Icons.arrow_downward_rounded,
          onChanged: (v) => setState(() => _lightLow = v),
          displayFormat: (v) =>
              v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : v.toStringAsFixed(0),
        ),

        const SizedBox(height: 8),

        // ── Độ ẩm đất ──
        _SectionHeader(
          title: 'ĐỘ ẨM ĐẤT',
          subtitle: 'Qua LoRa',
          icon: Icons.grass_rounded,
          color: const Color(0xFF8B4513),
        ),
        _ThresholdTile(
          label: 'Cảnh báo cao',
          value: _soilHigh,
          unit: '%',
          min: 50,
          max: 100,
          divisions: 50,
          color: const Color(0xFFDC2626),
          icon: Icons.arrow_upward_rounded,
          onChanged: (v) => setState(() => _soilHigh = v),
        ),
        _ThresholdTile(
          label: 'Cảnh báo thấp',
          value: _soilLow,
          unit: '%',
          min: 0,
          max: 50,
          divisions: 50,
          color: const Color(0xFF3B82F6),
          icon: Icons.arrow_downward_rounded,
          onChanged: (v) => setState(() => _soilLow = v),
        ),

        const SizedBox(height: 16),

        // ── Thông tin hệ thống ──
        _SectionHeader(
          title: 'THÔNG TIN HỆ THỐNG',
          subtitle: 'Kết nối & phần cứng',
          icon: Icons.developer_board_rounded,
          color: const Color(0xFF16A34A),
        ),
        _InfoTile(label: 'MQTT Broker', value: 'broker.hivemq.com:1883'),
        _InfoTile(label: 'Firestore', value: 'appnongnghiep-f9d6f'),
        _InfoTile(label: 'Chu kỳ đo', value: '30 giây → mỗi 3 phút'),
        
        const SizedBox(height: 16),

        // ── Tài khoản ──
        _SectionHeader(
          title: 'TÀI KHOẢN',
          subtitle: 'Quản lý bảo mật',
          icon: Icons.security_rounded,
          color: const Color(0xFF475569),
        ),
        GestureDetector(
          onTap: _changePasswordDialog,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.password_rounded, size: 20, color: Color(0xFF475569)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Đổi mật khẩu',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ],
     ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                    fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Threshold Tile ──────────────────────────────────────────────

class _ThresholdTile extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final IconData icon;
  final ValueChanged<double> onChanged;
  final String Function(double)? displayFormat;

  const _ThresholdTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.icon,
    required this.onChanged,
    this.displayFormat,
  });

  @override
  Widget build(BuildContext context) {
    final displayVal = displayFormat != null
        ? '${displayFormat!(value)} $unit'
        : '${value.toStringAsFixed(1)} $unit';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  displayVal,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              thumbColor: color,
              overlayColor: color.withOpacity(0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info Tile ───────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: Color(0xFF16A34A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}


