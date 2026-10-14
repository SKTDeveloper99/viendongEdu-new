import 'package:flutter/foundation.dart';

import '../../data/infinite_repository.dart';
import 'quest.dart';

/// State of the Viễn Đông Infinite screen: today's quests, what this phone
/// has claimed, and the equipped frame and title.
class InfiniteViewModel extends ChangeNotifier {
  InfiniteViewModel(this._repo, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final InfiniteRepository _repo;
  final DateTime Function() _now;

  QuestBook? _book;
  Set<String> _claimed = {};
  Set<String> _opened = {};
  Set<String> _unlocked = {};
  String? _frame;
  String? _title;
  String? _busyQuest;
  bool _disposed = false;

  List<Quest> get quests =>
      _book?.quests.where((q) => q.activeOn(_now())).toList() ?? const [];
  bool isClaimed(Quest q) => _claimed.contains(q.id);
  bool needsOpen(Quest q) => q.url != null && !_opened.contains(q.id);
  bool isBusy(Quest q) => _busyQuest == q.id;
  List<Cosmetic> get owned =>
      cosmetics.where((c) => _unlocked.contains(c.id)).toList();
  Cosmetic? get frame => _frame == null ? null : cosmeticById(_frame!);
  Cosmetic? get title => _title == null ? null : cosmeticById(_title!);

  Future<void> load() async {
    _book = _repo.loadBook();
    _claimed = await _repo.claimed();
    _opened = await _repo.opened();
    _unlocked = await _repo.unlocked();
    final eq = await _repo.equipped();
    _frame = eq['frame'];
    _title = eq['title'];
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
    if (isClaimed(q)) return 'Bạn đã nhận thưởng nhiệm vụ này rồi.';
    if (needsOpen(q)) return 'Mở liên kết của nhiệm vụ trước đã.';
    if (!q.codeMatches(typedCode)) {
      return 'Mã chưa đúng. Tìm lại trong bài đăng nhé.';
    }
    _busyQuest = q.id;
    _notify();
    try {
      final fix = await _repo.currentFix();
      if (fix.problem != null) return fix.problem!;
      if (!atSchool(_book!.school, fix.lat, fix.lng, fix.accuracyM)) {
        return 'Bạn chưa ở trường. Đến khuôn viên trường rồi thử lại.';
      }
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
      return 'Hoàn thành! Bạn nhận được: $names';
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
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
