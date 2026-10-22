/// PostgreSQL numeric columns may arrive as numbers or decimal strings.
/// Invalid and non-finite values stay unknown, never zero.
double? jsonDouble(dynamic value) {
  final number = value is num
      ? value.toDouble()
      : value is String
      ? double.tryParse(value.trim())
      : null;
  return number != null && number.isFinite ? number : null;
}

int? jsonInt(dynamic value) {
  if (value is int) return value;
  if (value is String) {
    final integer = int.tryParse(value.trim());
    if (integer != null) return integer;
  }
  final number = jsonDouble(value);
  // Do not silently round money, credits or identifiers in a malformed row.
  if (number == null || number.truncateToDouble() != number) return null;
  return number.toInt();
}

Map<String, dynamic>? jsonMap(dynamic value) =>
    value is Map<String, dynamic> ? value : null;
