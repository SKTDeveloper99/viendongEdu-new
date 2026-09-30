import '../../utils/vietnamese_text.dart';

/// School time (UTC+7) as HH:mm.
String schoolHhmm(DateTime d) {
  final school = d.toUtc().add(const Duration(hours: 7));
  return '${school.hour.toString().padLeft(2, '0')}:'
      '${school.minute.toString().padLeft(2, '0')}';
}

/// School time (UTC+7) as HH:mm:ss dd/MM/yyyy.
String schoolHhmmss(DateTime d) {
  final school = d.toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(school.hour)}:${two(school.minute)}:${two(school.second)} '
      '${two(school.day)}/${two(school.month)}/${school.year}';
}

String markLabel(String? mark) => switch (mark) {
  'present' => 'Có mặt',
  'absent' => 'Vắng',
  'late' => 'Đi trễ',
  'excused' => 'Vắng có phép',
  _ => 'Chưa điểm danh',
};

/// "Nguyễn Thị Lan Phương" -> "phuong|nguyen thi lan phuong".
String givenNameSortKey(String fullName) {
  final plain = stripVietnamese(fullName).toLowerCase().trim();
  final parts = plain.split(RegExp(r'\s+'));
  final given = parts.isEmpty ? '' : parts.last;
  return '$given|$plain';
}
