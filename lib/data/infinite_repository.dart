import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/remote/app_remote_config.dart';
import '../features/infinite/pet.dart';
import '../features/infinite/quest.dart';
import '../services/app_session.dart';
import 'infinite_cloud.dart';

export 'infinite_cloud.dart' show CloudVerdict;

/// A GPS fix, or why there is none.
class Fix {
  const Fix(this.lat, this.lng, this.accuracyM) : problem = null;
  const Fix.failed(this.problem) : lat = 0, lng = 0, accuracyM = 0;
  final double lat;
  final double lng;
  final double accuracyM;
  final String? problem;
}

/// Quest book, GPS and per-student progress.
///
/// Progress is written on the phone first (always works) and mirrored to
/// Firestore through [InfiniteCloud] when Firebase is reachable.
class InfiniteRepository {
  InfiniteRepository({InfiniteCloud? cloud}) : _cloud = cloud;

  final InfiniteCloud? _cloud;
  InfiniteCloud get cloud => _cloud ?? (_sharedCloud ??= InfiniteCloud());
  static InfiniteCloud? _sharedCloud;

  String get _who => AppSession.instance.mssv ?? 'guest';
  String _k(String name) => 'infinite.$_who.$name';
  static const _lastGoodKey = 'infinite.book_v2.last_good';

  /// Remote Config, else the last book that parsed on this phone, else the
  /// built-in one. A good remote book becomes the new last-good copy.
  Future<QuestBook> loadBook() async {
    final p = await SharedPreferences.getInstance();
    final remote = AppRemoteConfig.bookJson;
    if (remote.isNotEmpty) {
      final book = parseQuestBook(remote);
      if (book != null) {
        await p.setString(_lastGoodKey, remote);
        return book;
      }
    }
    final cached = p.getString(_lastGoodKey);
    return (cached == null ? null : parseQuestBook(cached)) ??
        parseQuestBook(defaultQuestsJson)!;
  }

  Future<Set<String>> cloudClaimed() => cloud.claimed(_who);

  Future<CloudVerdict> cloudClaim(Quest q, String code, Fix? fix) =>
      cloud.claim(
        _who,
        q,
        code: code,
        lat: fix?.lat,
        lng: fix?.lng,
        accuracyM: fix?.accuracyM,
      );

  Future<void> cloudEquip(String? frame, String? title) =>
      cloud.equip(_who, frame, title);

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

  Future<InfinitePet> selectedPet() async {
    final key = _k('pet');
    return InfinitePet.fromStored(
      (await SharedPreferences.getInstance()).getString(key),
    );
  }

  Future<void> selectPet(InfinitePet pet) async {
    final key = _k('pet');
    await (await SharedPreferences.getInstance()).setString(key, pet.name);
  }

  Future<void> _addTo(String name, Iterable<String> ids) async {
    final p = await SharedPreferences.getInstance();
    final s = (p.getStringList(_k(name)) ?? const []).toSet()..addAll(ids);
    await p.setStringList(_k(name), s.toList());
  }

  Future<void> markOpened(String questId) => _addTo('opened', [questId]);

  Future<void> markClaimed(Quest q) => markClaimedIds([q.id], q.rewards);

  Future<void> markClaimedIds(
    Iterable<String> ids,
    Iterable<String> rewards,
  ) async {
    await _addTo('claimed', ids);
    await _addTo('unlocked', rewards);
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
