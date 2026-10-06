/// "Chào buổi sáng," / "Chào buổi chiều," / "Chào buổi tối," from device time
/// (hour < 12 sáng, < 18 chiều, else tối).
String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Chào buổi sáng,';
  if (now.hour < 18) return 'Chào buổi chiều,';
  return 'Chào buổi tối,';
}

/// Which chalk doodle the home header draws beside the greeting.
enum DoodleScene { sunrise, sunCloud, moonStars, sleepyMoon }

/// Device-time doodle: 4–11 sunrise, 12–17 sun + cloud, 18–21 moon + stars,
/// 22–3 sleepy moon.
DoodleScene doodleSceneFor(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 12) return DoodleScene.sunrise;
  if (h >= 12 && h < 18) return DoodleScene.sunCloud;
  if (h >= 18 && h < 22) return DoodleScene.moonStars;
  return DoodleScene.sleepyMoon;
}
