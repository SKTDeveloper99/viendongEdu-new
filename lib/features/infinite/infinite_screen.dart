import 'package:flutter/material.dart';

import '../../data/infinite_repository.dart';
import '../../services/app_session.dart';
import '../../theme/vd_tokens.dart';
import 'infinite_view_model.dart';
import 'quest.dart';
import 'widgets/cosmetic_avatar.dart';
import 'widgets/quest_card.dart';
import 'widgets/lobby_hero.dart';
import 'widgets/school_map.dart';

/// Viễn Đông Infinite: quests at school, cosmetics as rewards.
class InfiniteScreen extends StatefulWidget {
  const InfiniteScreen({super.key, this.repository});

  final InfiniteRepository? repository;

  @override
  State<InfiniteScreen> createState() => _InfiniteScreenState();
}

class _InfiniteScreenState extends State<InfiniteScreen> {
  late final InfiniteViewModel _vm = InfiniteViewModel(
    widget.repository ?? InfiniteRepository(),
  )..load();

  @override
  void dispose() {
    _messageTick.dispose();
    _vm.dispose();
    super.dispose();
  }

  /// Last failed attempt per quest, shown inside its card (a SnackBar
  /// would sit behind an open pin sheet).
  final _messages = <String, String>{};
  final _messageTick = ValueNotifier(0);
  BuildContext? _sheet;

  Future<void> _claim(Quest quest, String code) async {
    if (_messages.remove(quest.id) != null) _messageTick.value++;
    final msg = await _vm.claim(quest, code);
    if (!mounted) return;
    if (_vm.isClaimed(quest)) {
      _messages.remove(quest.id);
      final sheet = _sheet;
      if (sheet != null && sheet.mounted) Navigator.of(sheet).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      setState(() => _messages[quest.id] = msg);
      _messageTick.value++;
    }
  }

  QuestCard _card(Quest q, {EdgeInsets? margin}) => QuestCard(
    key: ValueKey(q.id),
    quest: q,
    rewards: q.rewards.map(_vm.cosmeticById).nonNulls.toList(),
    claimed: _vm.isClaimed(q),
    needsOpen: _vm.needsOpen(q),
    busy: _vm.isBusy(q),
    onOpen: () => _vm.openLink(q),
    onClaim: (code) => _claim(q, code),
    message: _messages[q.id],
    margin: margin ?? const EdgeInsets.fromLTRB(16, 0, 16, 14),
  );

  Future<void> _openPin(Quest q) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.vd.bg,
      builder: (sheet) {
        _sheet = sheet;
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: 12 + MediaQuery.viewInsetsOf(sheet).bottom,
          ),
          child: ListenableBuilder(
            listenable: Listenable.merge([_vm, _messageTick]),
            builder: (_, _) => _card(q),
          ),
        );
      },
    );
    _sheet = null;
  }

  @override
  Widget build(BuildContext context) {
    final name = AppSession.instance.fullName ?? '';
    return Scaffold(
      backgroundColor: context.vd.bg,
      appBar: AppBar(title: const Text('Viễn Đông Infinite')),
      body: ListenableBuilder(
        listenable: _vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            if (!_vm.loaded)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!_vm.enabled)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _vm.notice ?? 'Sân chơi đang bảo trì. Quay lại sau nhé!',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._game(context, name),
          ],
        ),
      ),
    );
  }

  List<Widget> _game(BuildContext context, String name) => [
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SchoolMap(
        map: _vm.book!.map,
        quests: _vm.quests,
        isClaimed: _vm.isClaimed,
        onTap: _openPin,
      ),
    ),
    Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Text(
        'Chạm vào điểm trên bản đồ để mở nhiệm vụ.',
        style: TextStyle(color: context.vd.inkFaint, fontSize: 12),
      ),
    ),
    LobbyHero(
      name: name,
      frame: _vm.frame,
      title: _vm.title,
      completed: _vm.playable.where(_vm.isClaimed).length,
      total: _vm.playable.length,
    ),
    _heading(context, 'Nhiệm vụ'),
    if (_vm.quests.isEmpty)
      const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Chưa có nhiệm vụ mới. Quay lại sau nhé!'),
      ),
    for (final q in _vm.quests) _card(q),
    _heading(context, 'Bộ sưu tập'),
    if (_vm.owned.isEmpty)
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('Hoàn thành nhiệm vụ để mở khóa khung và danh hiệu.'),
      ),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _vm.owned.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          mainAxisExtent: 176,
        ),
        itemBuilder: (context, index) {
          final c = _vm.owned[index];
          return CosmeticTile(
            cosmetic: c,
            equipped: c.id == _vm.frame?.id || c.id == _vm.title?.id,
            onTap: () => _vm.equip(c),
          );
        },
      ),
    ),
  ];

  Widget _heading(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: context.vd.ink,
      ),
    ),
  );
}
