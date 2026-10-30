import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../models/sensor_data.dart';

// ── Time Range ──────────────────────────────────────────────────

enum TimeRange {
  hour6(Duration(hours: 6), '6 giờ'),
  hour12(Duration(hours: 12), '12 giờ'),
  hour18(Duration(hours: 18), '18 giờ');

  final Duration duration;
  final String label;
  const TimeRange(this.duration, this.label);
}

// ── History Screen ──────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  TimeRange _selectedRange = TimeRange.hour6;
  DateTime? _selectedDate;
  List<SensorData> _data = [];
  bool _loading = true;
  String? _error;
  StreamSubscription<List<SensorData>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _subscribeStream();
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  void _subscribeStream() {
    _streamSub?.cancel();
    setState(() { _loading = true; _error = null; });

    if (_selectedDate != null) {
      FirebaseService.instance
          .fetchHistory(date: _selectedDate)
          .then((result) {
        if (mounted) setState(() { _data = result; _loading = false; });
      }).catchError((e) {
        if (mounted) setState(() { _error = e.toString(); _loading = false; });
      });
    } else {
      _streamSub = FirebaseService.instance
          .historyStream(range: _selectedRange.duration)
          .listen(
        (result) {
          if (mounted) setState(() { _data = result; _loading = false; });
        },
        onError: (e) {
          debugPrint('[HistoryScreen] stream error: $e');
          if (mounted) setState(() { _error = e.toString(); _loading = false; });
        },
      );
    }
  }

  void _onRangeChanged(TimeRange r) {
    if (_selectedRange == r && _selectedDate == null) return;
    setState(() { _selectedRange = r; _selectedDate = null; });
    _subscribeStream();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFEF4444),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF0F172A),
          ),
        ),
        child: child!,
      ),
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
      _subscribeStream();
    }
  }

  Future<void> _refresh() async {
    _subscribeStream();
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          _TimeRangeSelector(
            selected: _selectedRange,
            selectedDate: _selectedDate,
            onChanged: _onRangeChanged,
            onPickDate: _pickDate,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
                : _error != null
                    ? _ErrorView(message: _error!, onRetry: _refresh)
                    : _data.isEmpty
                        ? _EmptyView(range: _selectedRange, selectedDate: _selectedDate)
                        : _HistoryBody(
                            data: _data,
                            range: _selectedRange,
                            onRefresh: _refresh,
                          ),
          ),
        ],
      ),
    );
  }
}

// ── Time Range Selector ─────────────────────────────────────────

class _TimeRangeSelector extends StatelessWidget {
  final TimeRange selected;
  final DateTime? selectedDate;
  final ValueChanged<TimeRange> onChanged;
  final VoidCallback onPickDate;

  const _TimeRangeSelector({
    required this.selected,
    this.selectedDate,
    required this.onChanged,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            ...TimeRange.values.map((r) {
              final isSelected = r == selected && selectedDate == null;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(r),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        r.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onPickDate,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: EdgeInsets.symmetric(
                    horizontal: selectedDate != null ? 12 : 10, vertical: 10),
                decoration: BoxDecoration(
                  color: selectedDate != null ? const Color(0xFF16A34A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selectedDate != null
                      ? [BoxShadow(color: const Color(0xFF16A34A).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded, size: 16,
                        color: selectedDate != null ? Colors.white : const Color(0xFF64748B)),
                    if (selectedDate != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd/MM').format(selectedDate!),
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Body (scrollable content) ──────────────────────────

class _HistoryBody extends StatefulWidget {
  final List<SensorData> data;
  final TimeRange range;
  final Future<void> Function() onRefresh;

  const _HistoryBody({required this.data, required this.range, required this.onRefresh});

  @override
  State<_HistoryBody> createState() => _HistoryBodyState();
}

class _HistoryBodyState extends State<_HistoryBody> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void didUpdateWidget(covariant _HistoryBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _visible = false;
      Future.delayed(const Duration(milliseconds: 60), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: const Color(0xFFEF4444),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
          children: [
            // ── Summary cards ──
            _SummaryStrip(data: widget.data),
            const SizedBox(height: 18),

            // ── Temperature chart (zoomable) ──
            _ZoomableChartCard(
              title: 'Nhiệt độ',
              unit: '°C',
              color: const Color(0xFFEF4444),
              fillColor: const Color(0xFFEF4444),
              icon: Icons.thermostat_rounded,
              data: widget.data,
              getValue: (d) => d.tempValid ? d.temp : null,
              autoFitY: true,   // tight Y-axis to show differences
              yPadding: 0.8,    // 0.8°C padding top/bottom
            ),
            const SizedBox(height: 16),

            // ── Humidity chart (zoomable) ──
            _ZoomableChartCard(
              title: 'Độ ẩm',
              unit: '%',
              color: const Color(0xFF3B82F6),
              fillColor: const Color(0xFF3B82F6),
              icon: Icons.water_drop_rounded,
              data: widget.data,
              getValue: (d) => d.humValid ? d.humidity : null,
              autoFitY: true,
              yPadding: 2.0,
            ),
            const SizedBox(height: 16),

            // ── Light chart (zoomable) ──
            _ZoomableChartCard(
              title: 'Cường độ ánh sáng',
              unit: 'lux',
              color: const Color(0xFFF59E0B),
              fillColor: const Color(0xFFF59E0B),
              icon: Icons.wb_sunny_rounded,
              data: widget.data,
              getValue: (d) => d.lightValid ? d.light : null,
              autoFitY: false,
              yPadding: 5.0,
              ),
              const SizedBox(height: 16),

              // --- Soil Moisture chart ---
              _ZoomableChartCard(
                title: 'Do am dat',
                unit: '%',
                color: const Color(0xFF10B981),
                fillColor: const Color(0xFF10B981),
                icon: Icons.grass_rounded,
                data: widget.data,
                getValue: (d) => d.soilValid ? d.soilMoisture : null,
                autoFitY: true,
                yPadding: 5.0,
              ),
              const SizedBox(height: 20),

              // --- Data table ---
              _DataTable(data: widget.data),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  ZOOMABLE CHART CARD — pinch zoom + drag pan
// ══════════════════════════════════════════════════════════════

class _ZoomableChartCard extends StatefulWidget {
  final String title, unit;
  final Color color, fillColor;
  final IconData icon;
  final List<SensorData> data;
  final double? Function(SensorData) getValue;
  final bool autoFitY;
  final double yPadding;

  const _ZoomableChartCard({
    required this.title,
    required this.unit,
    required this.color,
    required this.fillColor,
    required this.icon,
    required this.data,
    required this.getValue,
    required this.autoFitY,
    required this.yPadding,
  });

  @override
  State<_ZoomableChartCard> createState() => _ZoomableChartCardState();
}

class _ZoomableChartCardState extends State<_ZoomableChartCard> {
  // All processed spots (full dataset)
  List<FlSpot> _allSpots = [];
  DateTime _baseline = DateTime.now();
  double _totalSeconds = 0;

  // View window (seconds from baseline)
  double _viewStart = 0;
  double _viewEnd = 0;

  // Gesture state
  double _scaleStartViewSpan = 0;
  double _panStartViewStart = 0;
  double _panStartX = 0;
  bool _isPinching = false;

  // Touch crosshair
  double? _touchX;

  @override
  void initState() {
    super.initState();
    _buildSpots();
  }

  @override
  void didUpdateWidget(covariant _ZoomableChartCard old) {
    super.didUpdateWidget(old);
    if (old.data != widget.data || old.getValue != widget.getValue) {
      _buildSpots();
    }
  }

  void _buildSpots() {
    final spots = <FlSpot>[];
    final validData = widget.data.where((d) => d.createdAt != null).toList();
    if (validData.isEmpty) {
      setState(() { _allSpots = []; });
      return;
    }
    final baseline = validData.first.createdAt!;
    for (final d in validData) {
      final v = widget.getValue(d);
      if (v == null || v.isNaN || v.isInfinite) continue;
      final x = d.createdAt!.difference(baseline).inSeconds.toDouble();
      spots.add(FlSpot(x, v));
    }

    final totalSec = validData.last.createdAt!.difference(baseline).inSeconds.toDouble();

    setState(() {
      _baseline = baseline;
      _allSpots = spots;
      _totalSeconds = totalSec > 0 ? totalSec : 1;
      // Default: show all data
      _viewStart = 0;
      _viewEnd = _totalSeconds;
    });
  }

  // Get spots visible in current view window
  List<FlSpot> get _visibleSpots {
    return _allSpots
        .where((s) => s.x >= _viewStart - 1 && s.x <= _viewEnd + 1)
        .toList();
  }

  // Compute Y bounds for visible spots only (tight fit)
  ({double minY, double maxY, double avg}) _computeY(List<FlSpot> spots) {
    if (spots.isEmpty) return (minY: 0, maxY: 100, avg: 50);
    final vals = spots.map((s) => s.y).toList();
    final dMin = vals.reduce(math.min);
    final dMax = vals.reduce(math.max);
    final avg = vals.reduce((a, b) => a + b) / vals.length;
    final pad = widget.yPadding;

    if (widget.autoFitY) {
      // Tight fit: zoom in to show variance clearly
      final spread = dMax - dMin;
      final extraPad = math.max(pad, spread * 0.15);
      return (
        minY: dMin - extraPad,
        maxY: dMax + extraPad,
        avg: avg,
      );
    } else {
      return (
        minY: math.max(0, dMin - pad),
        maxY: dMax + pad,
        avg: avg,
      );
    }
  }

  // ── Gesture handlers ──

  void _onScaleStart(ScaleStartDetails d) {
    _scaleStartViewSpan = _viewEnd - _viewStart;
    _panStartViewStart = _viewStart;
    _panStartX = d.localFocalPoint.dx;
    _isPinching = d.pointerCount > 1;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double chartWidth) {
    if (chartWidth <= 0) return;

    double newStart = _viewStart;
    double newEnd = _viewEnd;
    final currentSpan = newEnd - newStart;

    if (_isPinching && d.scale != 1.0) {
      // Pinch zoom: scale around focal point
      final newSpan = (_scaleStartViewSpan / d.scale).clamp(
        300.0,           // min 5 min view
        _totalSeconds,   // max full range
      );
      final focalFraction = d.localFocalPoint.dx / chartWidth;
      final focalX = _viewStart + focalFraction * currentSpan;
      newStart = focalX - newSpan * focalFraction;
      newEnd = newStart + newSpan;
    } else {
      // Pan: drag to scroll
      final dx = d.localFocalPoint.dx - _panStartX;
      final secondsPerPixel = currentSpan / chartWidth;
      final delta = dx * secondsPerPixel;
      newStart = _panStartViewStart - delta;
      newEnd = newStart + currentSpan;
    }

    // Clamp to valid range
    if (newStart < 0) {
      newEnd -= newStart;
      newStart = 0;
    }
    if (newEnd > _totalSeconds) {
      newStart -= (newEnd - _totalSeconds);
      newEnd = _totalSeconds;
    }
    newStart = newStart.clamp(0, _totalSeconds);
    newEnd = newEnd.clamp(newStart + 60, _totalSeconds);

    setState(() {
      _viewStart = newStart;
      _viewEnd = newEnd;
    });
  }

  void _onScaleEnd(ScaleEndDetails _) {
    _isPinching = false;
  }

  String _formatX(double xSeconds) {
    final t = _baseline.add(Duration(seconds: xSeconds.toInt()));
    return DateFormat('HH:mm').format(t);
  }

  @override
  Widget build(BuildContext context) {
    if (_allSpots.isEmpty) {
      return _EmptyChart(icon: widget.icon, color: widget.color);
    }

    final visible = _visibleSpots;
    final yBounds = _computeY(visible.isEmpty ? _allSpots : visible);
    final viewSpan = _viewEnd - _viewStart;

    // Find min/max points in visible range
    FlSpot? minSpot, maxSpot;
    if (visible.isNotEmpty) {
      minSpot = visible.reduce((a, b) => a.y < b.y ? a : b);
      maxSpot = visible.reduce((a, b) => a.y > b.y ? a : b);
    }

    // X-axis label interval (aim for ~5 labels)
    final labelIntervalSec = (viewSpan / 5).ceilToDouble().clamp(60.0, 86400.0);

    final yRange = yBounds.maxY - yBounds.minY;
    final yInterval = yRange > 0 ? (yRange / 4).ceilToDouble().clamp(0.1, 1e6) : 1.0;

    // Latest visible value
    final latestSpot = visible.isNotEmpty ? visible.last : _allSpots.last;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: widget.color.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [widget.color.withOpacity(0.18), widget.color.withOpacity(0.06)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, size: 20, color: widget.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title,
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(
                        '${visible.length} điểm  •  pinch zoom  •  kéo để xem',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                // Current value badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.color.withOpacity(0.2)),
                  ),
                  child: Text(
                    '${latestSpot.y.toStringAsFixed(1)} ${widget.unit}',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: widget.color),
                  ),
                ),
              ],
            ),
          ),

          // ── Min / Avg / Max row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                if (minSpot != null) ...[
                  _StatBadge(
                    label: 'Min',
                    value: '${minSpot.y.toStringAsFixed(1)} ${widget.unit}',
                    time: _formatX(minSpot.x),
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                ],
                _StatBadge(
                  label: 'TB',
                  value: '${yBounds.avg.toStringAsFixed(1)} ${widget.unit}',
                  time: '',
                  color: widget.color.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                if (maxSpot != null)
                  _StatBadge(
                    label: 'Max',
                    value: '${maxSpot.y.toStringAsFixed(1)} ${widget.unit}',
                    time: _formatX(maxSpot.x),
                    color: const Color(0xFFEF4444),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Zoom/Pan hint ──
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
            child: _ZoomIndicator(
              viewStart: _viewStart,
              viewEnd: _viewEnd,
              totalSeconds: _totalSeconds,
              baseline: _baseline,
              color: widget.color,
            ),
          ),

          // ── Chart with GestureDetector ──
          SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth;
                return GestureDetector(
                  onScaleStart: _onScaleStart,
                  onScaleUpdate: (d) => _onScaleUpdate(d, chartWidth),
                  onScaleEnd: _onScaleEnd,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, bottom: 8),
                    child: LineChart(
                      LineChartData(
                        minX: _viewStart,
                        maxX: _viewEnd,
                        minY: yBounds.minY,
                        maxY: yBounds.maxY,
                        clipData: const FlClipData.all(),

                        // ── Grid ──
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: yInterval,
                          verticalInterval: labelIntervalSec,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: const Color(0xFFE2E8F0).withOpacity(0.7),
                            strokeWidth: 1,
                            dashArray: [5, 4],
                          ),
                          getDrawingVerticalLine: (_) => FlLine(
                            color: const Color(0xFFF1F5F9),
                            strokeWidth: 1,
                          ),
                        ),

                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            bottom: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.6), width: 1),
                            left: BorderSide(color: const Color(0xFFE2E8F0).withOpacity(0.6), width: 1),
                          ),
                        ),

                        // ── Titles ──
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 46,
                              interval: yInterval,
                              getTitlesWidget: (v, meta) {
                                if (v == meta.max || v == meta.min) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    widget.unit == '°C' ? '${v.toStringAsFixed(1)}°' : v.toStringAsFixed(0),
                                    style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFADB5BD), fontWeight: FontWeight.w600),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: labelIntervalSec,
                              getTitlesWidget: (xSec, meta) {
                                if (xSec <= _viewStart + 10 || xSec >= _viewEnd - 10) return const SizedBox.shrink();
                                final t = _baseline.add(Duration(seconds: xSec.toInt()));
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    DateFormat('HH:mm').format(t),
                                    style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFADB5BD), fontWeight: FontWeight.w500),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // ── Avg line + Min/Max annotations ──
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: yBounds.avg,
                              color: widget.color.withOpacity(0.3),
                              strokeWidth: 1.5,
                              dashArray: [8, 5],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.only(right: 6, bottom: 2),
                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: widget.color.withOpacity(0.7)),
                                labelResolver: (_) => 'TB ${yBounds.avg.toStringAsFixed(1)}',
                              ),
                            ),
                            // Min line
                            if (minSpot != null)
                              HorizontalLine(
                                y: minSpot.y,
                                color: const Color(0xFF3B82F6).withOpacity(0.4),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.bottomLeft,
                                  padding: const EdgeInsets.only(left: 6, top: 2),
                                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w600, color: const Color(0xFF3B82F6)),
                                  labelResolver: (_) => '↓ ${minSpot!.y.toStringAsFixed(1)}',
                                ),
                              ),
                            // Max line
                            if (maxSpot != null)
                              HorizontalLine(
                                y: maxSpot.y,
                                color: const Color(0xFFEF4444).withOpacity(0.4),
                                strokeWidth: 1,
                                dashArray: [4, 4],
                                label: HorizontalLineLabel(
                                  show: true,
                                  alignment: Alignment.topLeft,
                                  padding: const EdgeInsets.only(left: 6, bottom: 2),
                                  style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
                                  labelResolver: (_) => '↑ ${maxSpot!.y.toStringAsFixed(1)}',
                                ),
                              ),
                          ],
                        ),

                        // ── Touch tooltip ──
                        lineTouchData: LineTouchData(
                          handleBuiltInTouches: true,
                          touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                            if (event is FlPanEndEvent || event is FlTapUpEvent || event is FlLongPressEnd) {
                              setState(() => _touchX = null);
                            }
                          },
                          touchTooltipData: LineTouchTooltipData(
                            tooltipRoundedRadius: 12,
                            tooltipPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            tooltipMargin: 10,
                            getTooltipColor: (_) => const Color(0xE60F172A),
                            getTooltipItems: (spots) => spots.map((s) {
                              final t = _baseline.add(Duration(seconds: s.x.toInt()));
                              return LineTooltipItem(
                                '${s.y.toStringAsFixed(widget.unit == '°C' ? 1 : 0)} ${widget.unit}\n',
                                GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w800),
                                children: [
                                  TextSpan(
                                    text: DateFormat('HH:mm  dd/MM').format(t),
                                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w400),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                          getTouchedSpotIndicator: (barData, indices) => indices.map((_) =>
                            TouchedSpotIndicatorData(
                              FlLine(color: widget.color.withOpacity(0.4), strokeWidth: 1.5, dashArray: [4, 4]),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                                  radius: 7,
                                  color: Colors.white,
                                  strokeWidth: 3,
                                  strokeColor: widget.color,
                                ),
                              ),
                            ),
                          ).toList(),
                        ),

                        // ── Line data ──
                        lineBarsData: [
                          LineChartBarData(
                            spots: visible.isEmpty ? _allSpots : visible,
                            isCurved: true,
                            curveSmoothness: 0.3,
                            preventCurveOverShooting: true,
                            gradient: LinearGradient(
                              colors: [widget.color.withOpacity(0.7), widget.color, widget.color.withOpacity(0.9)],
                            ),
                            barWidth: 2.5,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: visible.length <= 30,
                              getDotPainter: (spot, pct, bar, i) {
                                final isMin = minSpot != null && spot.x == minSpot.x && spot.y == minSpot.y;
                                final isMax = maxSpot != null && spot.x == maxSpot.x && spot.y == maxSpot.y;
                                if (isMin) {
                                  return FlDotCirclePainter(radius: 5, color: const Color(0xFF3B82F6), strokeWidth: 2, strokeColor: Colors.white);
                                }
                                if (isMax) {
                                  return FlDotCirclePainter(radius: 5, color: const Color(0xFFEF4444), strokeWidth: 2, strokeColor: Colors.white);
                                }
                                return FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: widget.color);
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  widget.fillColor.withOpacity(0.28),
                                  widget.fillColor.withOpacity(0.10),
                                  widget.fillColor.withOpacity(0.02),
                                  widget.fillColor.withOpacity(0.0),
                                ],
                                stops: const [0.0, 0.35, 0.7, 1.0],
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(milliseconds: 120),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Zoom Indicator Bar ─────────────────────────────────────────

class _ZoomIndicator extends StatelessWidget {
  final double viewStart, viewEnd, totalSeconds;
  final DateTime baseline;
  final Color color;

  const _ZoomIndicator({
    required this.viewStart,
    required this.viewEnd,
    required this.totalSeconds,
    required this.baseline,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSeconds <= 0) return const SizedBox.shrink();

    final startFrac = (viewStart / totalSeconds).clamp(0.0, 1.0);
    final endFrac = (viewEnd / totalSeconds).clamp(0.0, 1.0);
    final widthFrac = endFrac - startFrac;

    final startTime = baseline.add(Duration(seconds: viewStart.toInt()));
    final endTime = baseline.add(Duration(seconds: viewEnd.toInt()));

    // Show labels only when not showing full range
    final isFullRange = viewStart <= 1 && viewEnd >= totalSeconds - 1;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini scrollbar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  children: [
                    Container(height: 4, color: const Color(0xFFF1F5F9)),
                    FractionallySizedBox(
                      widthFactor: widthFrac.clamp(0.05, 1.0),
                      alignment: Alignment(startFrac * 2 - 1 + widthFrac, 0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isFullRange) ...[
                const SizedBox(height: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('HH:mm dd/MM').format(startTime),
                      style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)),
                    ),
                    Text(
                      DateFormat('HH:mm dd/MM').format(endTime),
                      style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Reset zoom button
        if (!isFullRange)
          GestureDetector(
            onTap: () {
              // Handled by parent — call setState via key or callback
              // For now show a hint
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Reset',
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: color),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Stat Badge ─────────────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final String label, value, time;
  final Color color;

  const _StatBadge({required this.label, required this.value, required this.time, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 9, color: color.withOpacity(0.7), fontWeight: FontWeight.w500)),
          Text(value, style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
          if (time.isNotEmpty)
            Text(time, style: GoogleFonts.inter(fontSize: 9, color: color.withOpacity(0.6))),
        ],
      ),
    );
  }
}

// ── Empty Chart ────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _EmptyChart({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color.withOpacity(0.3)),
            const SizedBox(height: 6),
            Text('Không có dữ liệu', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}

// ── Summary Strip ──────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final List<SensorData> data;
  const _SummaryStrip({required this.data});

  @override
  Widget build(BuildContext context) {
    final temps = data.where((d) => d.tempValid).map((d) => d.temp).toList();
    final hums = data.where((d) => d.humValid).map((d) => d.humidity).toList();
    final luxes = data.where((d) => d.lightValid).map((d) => d.light).toList();

    double? minTemp = temps.isEmpty ? null : temps.reduce(math.min);
    double? maxTemp = temps.isEmpty ? null : temps.reduce(math.max);
    double? avgTemp = temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length;
    double? minHum = hums.isEmpty ? null : hums.reduce(math.min);
    double? maxHum = hums.isEmpty ? null : hums.reduce(math.max);
    double? avgHum = hums.isEmpty ? null : hums.reduce((a, b) => a + b) / hums.length;
    double? avgLux = luxes.isEmpty ? null : luxes.reduce((a, b) => a + b) / luxes.length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.thermostat_rounded,
            color: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEF2F2),
            title: 'Nhiệt độ',
            value: avgTemp != null ? '${avgTemp.toStringAsFixed(1)}°' : '--',
            subtitle: minTemp != null && maxTemp != null
                ? '${minTemp.toStringAsFixed(1)}° – ${maxTemp.toStringAsFixed(1)}°'
                : 'Không có dữ liệu',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF3B82F6),
            bgColor: const Color(0xFFEFF6FF),
            title: 'Độ ẩm',
            value: avgHum != null ? '${avgHum.toStringAsFixed(0)}%' : '--',
            subtitle: minHum != null && maxHum != null
                ? '${minHum.toStringAsFixed(0)}% – ${maxHum.toStringAsFixed(0)}%'
                : 'Không có dữ liệu',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            icon: Icons.wb_sunny_rounded,
            color: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFFFBEB),
            title: 'Ánh sáng',
            value: avgLux != null
                ? avgLux >= 1000 ? '${(avgLux / 1000).toStringAsFixed(1)}k' : '${avgLux.toStringAsFixed(0)}'
                : '--',
            subtitle: '${data.length} điểm dữ liệu',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color, bgColor;
  final String title, value, subtitle;

  const _SummaryCard({
    required this.icon, required this.color, required this.bgColor,
    required this.title, required this.value, required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: color.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A))),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: color.withOpacity(0.7)),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Data Table ─────────────────────────────────────────────────

class _DataTable extends StatelessWidget {
  final List<SensorData> data;
  const _DataTable({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = data.reversed.take(50).toList();
    final hasMore = data.length > 50;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
            ),
            child: Row(
              children: [
                const Icon(Icons.table_chart_rounded, size: 16, color: Colors.white38),
                const SizedBox(width: 8),
                Expanded(flex: 4,
                    child: Text('Thời gian', style: GoogleFonts.inter(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w600))),
                SizedBox(width: 60, child: Text('Nhiệt độ', textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFFCA5A5), fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                SizedBox(width: 52, child: Text('Độ ẩm', textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF93C5FD), fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                SizedBox(width: 56, child: Text('Ánh sáng', textAlign: TextAlign.right,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFFCD34D), fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          ...rows.asMap().entries.map((e) => _TableRow(data: e.value, isEven: e.key.isEven)),
          if (hasMore)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              color: const Color(0xFFF8FAFC),
              child: Center(
                child: Text(
                  'Hiển thị 50 / ${data.length} mục gần nhất',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  final SensorData data;
  final bool isEven;
  const _TableRow({required this.data, required this.isEven});

  @override
  Widget build(BuildContext context) {
    final timeStr = data.createdAt != null
        ? DateFormat('HH:mm:ss  dd/MM').format(data.createdAt!)
        : data.timestamp;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
        border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4,
              child: Text(timeStr, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500))),
          SizedBox(width: 60, child: Text(
            data.tempValid ? '${data.temp.toStringAsFixed(1)}°C' : '--',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFEF4444), fontWeight: FontWeight.w700),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 52, child: Text(
            data.humValid ? '${data.humidity.toStringAsFixed(0)}%' : '--',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF3B82F6), fontWeight: FontWeight.w700),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 56, child: Text(
            data.lightValid
                ? data.light >= 1000 ? '${(data.light / 1000).toStringAsFixed(1)}k' : '${data.light.toStringAsFixed(0)}'
                : '--',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFF59E0B), fontWeight: FontWeight.w700),
          )),
          const SizedBox(width: 8),
          SizedBox(width: 45, child: Text(
            data.soilValid ? '${data.soilMoisture.toStringAsFixed(0)}%' : '--',
            textAlign: TextAlign.right,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981), fontWeight: FontWeight.w700),
          )),
        ],
      ),
    );
  }
}

// ── Empty & Error Views ─────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final TimeRange range;
  final DateTime? selectedDate;
  const _EmptyView({required this.range, this.selectedDate});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.show_chart_rounded, size: 48, color: Color(0xFFCBD5E1)),
        ),
        const SizedBox(height: 16),
        Text(
          selectedDate != null
              ? 'Không có dữ liệu ngày ${DateFormat('dd/MM/yyyy').format(selectedDate!)}'
              : 'Không có dữ liệu trong ${range.label} qua',
          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text('Kéo xuống để tải lại', style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFFCA5A5)),
        ),
        const SizedBox(height: 16),
        Text('Lỗi tải dữ liệu',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Thử lại'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    ),
  );
}




