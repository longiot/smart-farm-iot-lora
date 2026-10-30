import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/note_entry.dart';
import '../services/note_service.dart';

String _viMonth(DateTime d) {
  const months = [
    '', 'Tháng 1', 'Tháng 2', 'Tháng 3', 'Tháng 4',
    'Tháng 5', 'Tháng 6', 'Tháng 7', 'Tháng 8',
    'Tháng 9', 'Tháng 10', 'Tháng 11', 'Tháng 12',
  ];
  return '${months[d.month]} ${d.year}';
}

class NoteScreen extends StatefulWidget {
  const NoteScreen({super.key});

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _calendarMonth = DateTime.now();
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    if (!_formKey.currentState!.validate()) return;
    final service = context.read<NoteService>();
    final entry = NoteEntry(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      createdAt: DateTime.now(),
    );
    await service.addNote(entry);
    _titleCtrl.clear();
    _contentCtrl.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu ghi chú!', style: GoogleFonts.inter()),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _deleteNote(BuildContext ctx, String id) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Xóa ghi chú?', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
        content: Text('Hành động này không thể hoàn tác.', style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Huỷ', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Xóa', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<NoteService>().deleteNote(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NoteService>(
      builder: (context, service, _) {
        final datesWithNotes = service.getDatesWithNotes();
        final recentNotes = service.getRecentNotes(5);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: [
            // ── Calendar ──
            _buildCalendar(datesWithNotes),
            const SizedBox(height: 16),

            // ── Form ghi chú ──
            _buildNoteForm(),
            const SizedBox(height: 24),

            // ── Ghi chú của ngày đang chọn ──
            if (service.getNotesForDate(_selectedDate).isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GHI CHÚ NGÀY ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF16A34A),
                      letterSpacing: 1.1,
                      shadows: [Shadow(color: Colors.black12, blurRadius: 2)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...service.getNotesForDate(_selectedDate).map((n) => _NoteCard(
                    note: n,
                    onDelete: () => _deleteNote(context, n.id),
                  )),
              const SizedBox(height: 24),
            ],

            // ── Ghi chú gần đây ──
            if (recentNotes.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NHẬT KÝ GẦN ĐÂY',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.95),
                      letterSpacing: 1.1,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...recentNotes.map((n) => _NoteCard(
                    note: n,
                    onDelete: () => _deleteNote(context, n.id),
                  )),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCalendar(Set<DateTime> datesWithNotes) {
    final daysInMonth =
        DateUtils.getDaysInMonth(_calendarMonth.year, _calendarMonth.month);
    final firstWeekday =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday % 7;

    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Điều hướng tháng ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded,
                    color: Color(0xFF64748B)),
                onPressed: () => setState(() {
                  _calendarMonth = DateTime(
                      _calendarMonth.year, _calendarMonth.month - 1);
                }),
              ),
              Text(
                _viMonth(_calendarMonth),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFF64748B)),
                onPressed: () {
                  final next = DateTime(
                      _calendarMonth.year, _calendarMonth.month + 1);
                  if (!next.isAfter(DateTime.now())) {
                    setState(() => _calendarMonth = next);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Tiêu đề các ngày ──
          Row(
            children: ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']
                .map((d) => Expanded(
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),

          // ── Lưới ngày ──
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: firstWeekday + daysInMonth,
            itemBuilder: (ctx, i) {
              if (i < firstWeekday) return const SizedBox();
              final day = i - firstWeekday + 1;
              final date = DateTime(
                  _calendarMonth.year, _calendarMonth.month, day);
              final normalized =
                  DateTime(date.year, date.month, date.day);
              final isSelected = normalized.year == _selectedDate.year &&
                  normalized.month == _selectedDate.month &&
                  normalized.day == _selectedDate.day;
              final isToday = normalized == today;
              final hasNote = datesWithNotes.contains(normalized);
              final isFuture = normalized.isAfter(today);

              return GestureDetector(
                onTap: isFuture
                    ? null
                    : () => setState(() => _selectedDate = date),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFF16A34A)
                        : isToday
                            ? const Color(0xFF16A34A).withOpacity(0.1)
                            : Colors.transparent,
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF16A34A).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: isSelected || isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : isFuture
                                  ? const Color(0xFFCBD5E1)
                                  : isToday
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Chấm xanh / vàng = ngày có ghi chú
                      if (hasNote)
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // ── Nhãn ngày đang chọn ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded,
                    size: 14, color: Color(0xFF16A34A)),
                const SizedBox(width: 8),
                Text(
                  'Ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16A34A).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_document,
                      color: Color(0xFF16A34A), size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  'Thêm công việc',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tiêu đề
            TextFormField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                hintText: 'Tiêu đề (vd: Bón phân, Tưới nước...)',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF16A34A), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w600),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Vui lòng nhập tiêu đề'
                  : null,
            ),
            const SizedBox(height: 12),

            // Nội dung
            TextFormField(
              controller: _contentCtrl,
              decoration: InputDecoration(
                hintText: 'Nội dung chi tiết...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF16A34A), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
              style: GoogleFonts.inter(fontSize: 14),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _saveNote,
                icon: const Icon(Icons.add_task_rounded, size: 18),
                label: Text('Lưu nhật ký',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                  shadowColor: const Color(0xFF16A34A).withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NoteEntry note;
  final VoidCallback onDelete;

  const _NoteCard({required this.note, required this.onDelete});

  Color get _accentColor {
    const colors = [
      Color(0xFFF59E0B),
      Color(0xFF16A34A),
      Color(0xFF0284C7),
      Color(0xFF8B5CF6),
      Color(0xFFE11D48),
    ];
    return colors[note.id.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border(left: BorderSide(color: _accentColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.sticky_note_2_rounded, color: _accentColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(note.date),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (note.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    note.content,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF475569),
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 16, color: Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }
}
