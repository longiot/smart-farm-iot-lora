import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note_entry.dart';

class NoteService extends ChangeNotifier {
  List<NoteEntry> _notes = [];
  List<NoteEntry> get notes => List.unmodifiable(_notes);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? _deviceId;
  StreamSubscription? _sub;

  void setDeviceId(String deviceId) {
    if (_deviceId == deviceId) return;
    _deviceId = deviceId;
    _sub?.cancel();
    _notes.clear();

    _sub = _db.collection('devices').doc(_deviceId).collection('notes').snapshots().listen((snap) {
      _notes = snap.docs.map((doc) {
        final d = doc.data();
        return NoteEntry(
          id: doc.id,
          date: d['date'] is Timestamp ? (d['date'] as Timestamp).toDate() : DateTime.now(),
          title: d['title'] as String? ?? '',
          content: d['content'] as String? ?? '',
          createdAt: d['createdAt'] is Timestamp ? (d['createdAt'] as Timestamp).toDate() : DateTime.now(),
        );
      }).toList();
      
      // Sắp xếp theo ngày giảm dần, rồi đến thời gian tạo giảm dần
      _notes.sort((a, b) {
         int cmp = b.date.compareTo(a.date);
         if (cmp == 0) {
            return b.createdAt.compareTo(a.createdAt);
         }
         return cmp;
      });
      notifyListeners();
    }, onError: (e) {
      debugPrint('[NoteService] Firestore listen error: $e');
    });
  }

  Future<void> init() async {}

  Future<void> addNote(NoteEntry note) async {
    if (_deviceId == null) return;
    await _db.collection('devices').doc(_deviceId).collection('notes').doc(note.id).set({
      'date': Timestamp.fromDate(note.date),
      'title': note.title,
      'content': note.content,
      'createdAt': Timestamp.fromDate(note.createdAt),
    });
  }

  Future<void> deleteNote(String id) async {
    if (_deviceId == null) return;
    await _db.collection('devices').doc(_deviceId).collection('notes').doc(id).delete();
  }

  /// Trả về N ghi chú gần nhất
  List<NoteEntry> getRecentNotes([int count = 5]) {
    return _notes.take(count).toList();
  }

  /// Trả về set các ngày đã có ghi chú (dùng để highlight trên lịch)
  Set<DateTime> getDatesWithNotes() {
    return _notes
        .map((n) => DateTime(n.date.year, n.date.month, n.date.day))
        .toSet();
  }

  /// Lấy ghi chú của một ngày cụ thể
  List<NoteEntry> getNotesForDate(DateTime date) {
    return _notes.where((n) =>
        n.date.year == date.year &&
        n.date.month == date.month &&
        n.date.day == date.day).toList();
  }
}
