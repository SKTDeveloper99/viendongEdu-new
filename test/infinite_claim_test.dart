import 'package:flutter_test/flutter_test.dart';
import 'package:viendongedu2_flutter/data/infinite_repository.dart';
import 'package:viendongedu2_flutter/features/infinite/infinite_view_model.dart';
import 'package:viendongedu2_flutter/features/infinite/quest.dart';

/// Phone storage in memory, a fixed GPS fix and a scripted cloud verdict.
class _FakeRepo extends InfiniteRepository {
  _FakeRepo({this.verdict = CloudVerdict.saved, this.cloudIds = const {}});
  CloudVerdict verdict;
  final Set<String> cloudIds;
  final claimedIds = <String>{};
  final unlockedIds = <String>{};
  final eq = <String, String?>{};
  var fix = const Fix(10.851835539538312, 106.62820562524071, 10);
  int gpsCalls = 0;

  @override
  Future<QuestBook> loadBook() async => parseQuestBook(defaultQuestsJson)!;
  @override
  Future<Set<String>> claimed() async => {...claimedIds};
  @override
  Future<Set<String>> opened() async => {'tiktok-1', 'fanpage-1'};
  @override
  Future<Set<String>> unlocked() async => {...unlockedIds};
  @override
  Future<Map<String, String?>> equipped() async => {...eq};
  @override
  Future<void> markClaimedIds(
    Iterable<String> ids,
    Iterable<String> rewards,
  ) async {
    claimedIds.addAll(ids);
    unlockedIds.addAll(rewards);
  }

  @override
  Future<void> equip(String slot, String? id) async => eq[slot] = id;
  @override
  Future<Fix> currentFix() async {
    gpsCalls++;
    return fix;
  }

  @override
  Future<Set<String>> cloudClaimed() async => cloudIds;
  @override
  Future<CloudVerdict> cloudClaim(Quest q, String code, Fix? fix) async =>
      verdict;
  @override
  Future<void> cloudEquip(String? frame, String? title) async {}
}

Quest _q(InfiniteViewModel vm, String id) =>
    vm.quests.firstWhere((q) => q.id == id);

void main() {
  test('right quiz answer unlocks and auto-equips; no GPS needed', () async {
    final repo = _FakeRepo();
    final vm = InfiniteViewModel(repo);
    await vm.load();
    final msg = await vm.claim(_q(vm, 'quiz-1'), 'Khung và danh hiệu');
    expect(msg, startsWith('Hoàn thành!'));
    expect(repo.gpsCalls, 0);
    expect(vm.frame?.id, 'frame_teal');
    expect(vm.title?.id, 'title_scholar');
  });

  test('wrong code is refused on the phone, nothing granted', () async {
    final repo = _FakeRepo();
    final vm = InfiniteViewModel(repo);
    await vm.load();
    expect(await vm.claim(_q(vm, 'field-1'), 'WRONG'), contains('chưa đúng'));
    expect(await vm.claim(_q(vm, 'field-1'), ''), contains('Nhập mã'));
    expect(repo.claimedIds, isEmpty);
  });

  test('server refusal grants nothing', () async {
    final repo = _FakeRepo(verdict: CloudVerdict.refused);
    final vm = InfiniteViewModel(repo);
    await vm.load();
    expect(await vm.claim(_q(vm, 'checkin-1'), ''), contains('Máy chủ'));
    expect(vm.isClaimed(_q(vm, 'checkin-1')), isFalse);
  });

  test('offline claim is granted now and marked to sync', () async {
    final repo = _FakeRepo(verdict: CloudVerdict.queued);
    final vm = InfiniteViewModel(repo);
    await vm.load();
    expect(await vm.claim(_q(vm, 'checkin-1'), ''), contains('đồng bộ'));
    expect(repo.claimedIds, {'checkin-1'});
  });

  test('Firebase off still plays on the phone', () async {
    final repo = _FakeRepo(verdict: CloudVerdict.off);
    final vm = InfiniteViewModel(repo);
    await vm.load();
    expect(await vm.claim(_q(vm, 'checkin-1'), ''), startsWith('Hoàn thành!'));
  });

  test('away from school is refused for at-school quests', () async {
    final repo = _FakeRepo()..fix = const Fix(10.9, 106.7, 10);
    final vm = InfiniteViewModel(repo);
    await vm.load();
    expect(await vm.claim(_q(vm, 'checkin-1'), ''), contains('chưa ở đúng'));
  });

  test('claims from another install come back from the cloud', () async {
    final repo = _FakeRepo(cloudIds: {'checkin-1', 'gone-quest'});
    final vm = InfiniteViewModel(repo);
    await vm.load();
    expect(vm.isClaimed(_q(vm, 'checkin-1')), isTrue);
    expect(vm.owned.map((c) => c.id), containsAll(['frame_blue']));
    expect(vm.cloudOn, isTrue);
  });
}
