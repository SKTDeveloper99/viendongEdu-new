import 'package:flutter/foundation.dart';

import '../../core/remote/app_remote_config.dart';
import '../../data/infinite_repository.dart';
import 'quest.dart';

/// State of the Viễn Đông Infinite screen: today's quests, what this student
/// has claimed (phone ∪ cloud), and the equipped frame and title.
class InfiniteViewModel extends ChangeNotifier {
  InfiniteViewModel(this._repo, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    AppRemoteConfig.changes.addListener(_reloadBook);
  }

  final InfiniteRepository _repo;
  final DateTime Function() _now;

  QuestBook? _book;
  Set<String> _claimed = {};
  Set<String> _opened = {};
  Set<String> _unlocked = {};
  String? _frame;
  String? _title;
  String? _busyQuest;
  bool _cloudOn = false;
  bool _disposed = false;

  QuestBook? get book => _book;
  bool get loaded => _book != null;
  bool get enabled => _book?.enabled ?? true;
  String? get notice => _book?.notice;

  /// True once Firestore answered at least once this session.
  bool get cloudOn => _cloudOn;

  List<Quest> get quests =>
      _book?.quests.where((q) => q.activeOn(_now())).toList() ?? const [];
  List<Quest> get playable => quests.where((q) => q.playable).toList();
  bool isClaimed(Quest q) => _claimed.contains(q.id);
  bool needsOpen(Quest q) => q.url != null && !_opened.contains(q.id);
  bool isBusy(Quest q) => _busyQuest == q.id;
  Cosmetic? cosmeticById(String id) => _book?.cosmeticById(id);
  List<Cosmetic> get owned =>
      _book?.cosmetics.where((c) => _unlocked.contains(c.id)).toList() ??
      const [];
  Cosmetic? get frame => _frame == null ? null : cosmeticById(_frame!);
  Cosmetic? get title => _title == null ? null : cosmeticById(_title!);

  Future<void> load() async {
    _book = await _repo.loadBook();
    _claimed = await _repo.claimed();
    _opened = await _repo.opened();
    _unlocked = await _repo.unlocked();
    final eq = await _repo.equipped();
    _frame = eq['frame'];
    _title = eq['title'];
    _notify();
    await _mergeCloud();
  }

  Future<void> _reloadBook() async {
    _book = await _repo.loadBook();
    _notify();
  }

  /// Claims made on another install come back from Firestore.
  Future<void> _mergeCloud() async {
    final cloud = await _repo.cloudClaimed();
    if (cloud.isEmpty) return;
    _cloudOn = true;
    final fresh = cloud.difference(_claimed);
    if (fresh.isNotEmpty) {
      final rewards = [
        for (final q in _book?.quests ?? const <Quest>[])
          if (fresh.contains(q.id)) ...q.rewards,
      ];
      await _repo.markClaimedIds(fresh, rewards);
      _claimed = {..._claimed, ...fresh};
      _unlocked = {..._unlocked, ...rewards};
    }
    _notify();
  }

  Future<void> openLink(Quest q) async {
    if (q.url == null) return;
    await _repo.openLink(q.url!);
    await _repo.markOpened(q.id);
    _opened = {..._opened, q.id};
    _notify();
  }

  /// Returns the message to show. Success unlocks and auto-equips rewards
  /// the student has nothing equipped for.
  Future<String> claim(Quest q, String typedCode) async {
    if (!q.playable) return 'Cập nhật ứng dụng để chơi nhiệm vụ này.';
    if (isClaimed(q)) return 'Bạn đã nhận thưởng nhiệm vụ này rồi.';
    if (needsOpen(q)) return 'Mở liên kết của nhiệm vụ trước đã.';
    if (q.needsCode && typedCode.trim().isEmpty) {
      return switch (q.kind) {
        QuestKind.quiz => 'Chọn một đáp án trước đã.',
        QuestKind.qr => 'Quét mã QR hoặc nhập dòng chữ dưới mã.',
        _ => 'Nhập mã trước đã.',
      };
    }
    if (!q.codeMatches(typedCode)) {
      return switch (q.kind) {
        QuestKind.quiz => 'Chưa đúng rồi. Thử lại nhé!',
        QuestKind.qr => 'Mã QR này không thuộc nhiệm vụ. Tìm đúng mã nhé.',
        _ => 'Mã chưa đúng. Tìm lại nhé.',
      };
    }
    _busyQuest = q.id;
    _notify();
    try {
      Fix? fix;
      if (q.atSchool) {
        fix = await _repo.currentFix();
        if (fix.problem != null) return fix.problem!;
        if (!atSchool(
          q.place ?? _book!.school,
          fix.lat,
          fix.lng,
          fix.accuracyM,
        )) {
          return 'Bạn chưa ở đúng địa điểm. Đến khuôn viên trường rồi thử lại.';
        }
      }
      final verdict = await _repo.cloudClaim(q, typedCode, fix);
      if (verdict == CloudVerdict.refused) {
        return 'Máy chủ chưa xác nhận nhiệm vụ này (có thể đã hết hạn). '
            'Thử lại sau nhé.';
      }
      if (verdict == CloudVerdict.saved) _cloudOn = true;
      await _repo.markClaimed(q);
      _claimed = {..._claimed, q.id};
      _unlocked = {..._unlocked, ...q.rewards};
      for (final c in q.rewards.map(cosmeticById).nonNulls) {
        if (c.isFrame && _frame == null) await equip(c);
        if (!c.isFrame && _title == null) await equip(c);
      }
      final names = q.rewards
          .map(cosmeticById)
          .nonNulls
          .map((c) => c.title ?? c.name)
          .join(', ');
      final tail = verdict == CloudVerdict.queued
          ? ' (sẽ đồng bộ khi có mạng)'
          : '';
      return 'Hoàn thành! Bạn nhận được: $names$tail';
    } finally {
      _busyQuest = null;
      _notify();
    }
  }

  Future<void> equip(Cosmetic c) async {
    final slot = c.isFrame ? 'frame' : 'title';
    final current = c.isFrame ? _frame : _title;
    final next = current == c.id ? null : c.id;
    await _repo.equip(slot, next);
    if (c.isFrame) {
      _frame = next;
    } else {
      _title = next;
    }
    await _repo.cloudEquip(_frame, _title);
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    AppRemoteConfig.changes.removeListener(_reloadBook);
    super.dispose();
  }
}
