// Display formatting shared by the class manager widgets (unchanged).

/// ISO date -> dd/MM/yyyy; '' when empty; the raw text when unparseable.
String fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return iso;
  }
}

/// ISO date-time -> HH:mm; "HH:MM:SS" -> HH:mm; plain "HH:mm" passes through.
String fmtTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  if (raw.contains('T')) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {}
  }
  final m = RegExp(r'^(\d{1,2}:\d{2}):\d{2}(\.\d+)?$').firstMatch(raw);
  if (m != null) return m.group(1)!;
  return raw;
}
