/// "Chào buổi sáng," / "Chào buổi chiều," / "Chào buổi tối," from device time
/// (hour < 12 sáng, < 18 chiều, else tối).
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Chào buổi sáng,';
  if (now.hour < 18) return 'Chào buổi chiều,';
  return 'Chào buổi tối,';
}
