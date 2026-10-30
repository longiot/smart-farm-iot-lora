/// Model lưu một ghi chú lịch trình nông nghiệp
class NoteEntry {
  final String id;
  final DateTime date;
  final String title;
  final String content;
  final DateTime createdAt;

  NoteEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
      };

  factory NoteEntry.fromJson(Map<String, dynamic> j) => NoteEntry(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        title: j['title'] as String,
        content: j['content'] as String,
        createdAt: j['createdAt'] != null
            ? DateTime.parse(j['createdAt'] as String)
            : DateTime.parse(j['date'] as String),
      );
}
