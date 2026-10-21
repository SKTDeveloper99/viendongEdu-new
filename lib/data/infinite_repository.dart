import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/remote/app_remote_config.dart';
import '../features/infinite/pet.dart';
import '../features/infinite/quest.dart';
import '../services/app_session.dart';

/// A GPS fix, or why there is none.
class Fix {
  const Fix(this.lat, this.lng, this.accuracyM) : problem = null;
  const Fix.failed(this.problem) : lat = 0, lng = 0, accuracyM = 0;
  final double lat;
  final double lng;
  final double accuracyM;
  final String? problem;
}

/// Quest book, GPS and the per-student progress kept on this phone.
/// Progress is local only: reinstalling or changing phone starts over.
class InfiniteRepository {
  String get _who => AppSession.instance.mssv ?? 'guest';
  String _k(String name) => 'infinite.$_who.$name';

  QuestBook loadBook() =>
      parseQuestBook(AppRemoteConfig.questsJson) ??
      parseQuestBook(defaultQuestsJson)!;

  Future<Set<String>> claimed() async =>
      ((await SharedPreferences.getInstance()).getStringList(_k('claimed')) ??
              const [])
          .toSet();

  Future<Set<String>> opened() async =>
      ((await SharedPreferences.getInstance()).getStringList(_k('opened')) ??
              const [])
          .toSet();

  Future<Set<String>> unlocked() async =>
      ((await SharedPreferences.getInstance()).getStringList(_k('unlocked')) ??
              const [])
          .toSet();

  Future<Map<String, String?>> equipped() async {
    final p = await SharedPreferences.getInstance();
    return {
      'frame': p.getString(_k('frame')),
      'title': p.getString(_k('title')),
    };
  }

  Future<InfinitePet> selectedPet() async => InfinitePet.fromStored(
    (await SharedPreferences.getInstance()).getString(_k('pet')),
  );

  Future<void> selectPet(InfinitePet pet) async {
    await (await SharedPreferences.getInstance()).setString(
      _k('pet'),
      pet.name,
    );
  }

  Future<void> _addTo(String name, Iterable<String> ids) async {
    final p = await SharedPreferences.getInstance();
    final s = (p.getStringList(_k(name)) ?? const []).toSet()..addAll(ids);
    await p.setStringList(_k(name), s.toList());
  }

  Future<void> markOpened(String questId) => _addTo('opened', [questId]);

  Future<void> markClaimed(Quest q) async {
    await _addTo('claimed', [q.id]);
    await _addTo('unlocked', q.rewards);
  }

  Future<void> equip(String slot, String? id) async {
    final p = await SharedPreferences.getInstance();
    if (id == null) {
      await p.remove(_k(slot));
    } else {
      await p.setString(_k(slot), id);
    }
  }

  Future<bool> openLink(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  Future<Fix> currentFix() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Fix.failed('Hãy bật Định vị (GPS) trên điện thoại.');
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return const Fix.failed(
          'Ứng dụng cần quyền vị trí để xác nhận bạn đang ở trường. '
          'Mở Cài đặt để cho phép.',
        );
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return Fix(pos.latitude, pos.longitude, pos.accuracy);
    } catch (_) {
      return const Fix.failed('Chưa lấy được vị trí. Thử lại ngoài trời.');
    }
  }
}
