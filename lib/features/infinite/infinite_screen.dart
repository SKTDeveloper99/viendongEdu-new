import 'package:flutter/material.dart';

import '../../data/infinite_repository.dart';
import '../../services/app_session.dart';
import '../../theme/vd_tokens.dart';
import 'infinite_view_model.dart';
import 'quest.dart';
import 'widgets/cosmetic_avatar.dart';
import 'widgets/quest_card.dart';

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
    _vm.dispose();
    super.dispose();
  }

  Future<void> _claim(Quest quest, String code) async {
    final msg = await _vm.claim(quest, code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            const SizedBox(height: 16),
            Center(
              child: CosmeticAvatar(name: name, frame: _vm.frame),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_vm.title != null)
              Center(
                child: Text(
                  _vm.title!.title!,
                  style: TextStyle(
                    color: context.vd.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            _heading(context, 'Nhiệm vụ'),
            if (_vm.quests.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Chưa có nhiệm vụ mới. Quay lại sau nhé!'),
              ),
            for (final q in _vm.quests)
              QuestCard(
                key: ValueKey(q.id),
                quest: q,
                claimed: _vm.isClaimed(q),
                needsOpen: _vm.needsOpen(q),
                busy: _vm.isBusy(q),
                onOpen: () => _vm.openLink(q),
                onClaim: (code) => _claim(q, code),
              ),
            _heading(context, 'Bộ sưu tập'),
            if (_vm.owned.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Hoàn thành nhiệm vụ để mở khóa khung và danh hiệu.',
                ),
              ),
            for (final c in _vm.owned)
              CosmeticTile(
                cosmetic: c,
                equipped: c.id == _vm.frame?.id || c.id == _vm.title?.id,
                onTap: () => _vm.equip(c),
              ),
          ],
        ),
      ),
    );
  }

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
