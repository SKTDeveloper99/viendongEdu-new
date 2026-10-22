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
  final number = jsonDouble(value);
  return number?.toInt();
}

Map<String, dynamic>? jsonMap(dynamic value) =>
    value is Map<String, dynamic> ? value : null;
