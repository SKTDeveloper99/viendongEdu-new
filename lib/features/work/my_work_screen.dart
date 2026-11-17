import 'package:flutter/material.dart';

import '../../services/app_session.dart';
import '../../services/crm_session_guard.dart';
import '../../services/ems_api_service.dart';
import '../../theme/vd_tokens.dart';
import 'piece_screen.dart';
import '../work_home/hub_screens.dart' show GiveTaskScreen;
import 'work_api.dart';

part 'my_work_screen_parts_1.dart';

/// "Việc của tôi", native (Overlord slice): work I received, work I gave,
/// and the hand-ins waiting for me. A piece always opens on ONE screen
/// ([PieceScreen]) whichever list, bell or calendar line it came from.
class MyWorkScreen extends StatefulWidget {
  final int initialTab;
  const MyWorkScreen({super.key, this.initialTab = 0});

  @override
  State<MyWorkScreen> createState() => _MyWorkScreenState();
}

class _MyWorkScreenState extends State<MyWorkScreen> {
  List<Map<String, dynamic>>? _received;

  List<Map<String, dynamic>>? _given;

  String? _receivedError;

  String? _givenError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final vd = context.vd;
    final tabs = <Tab>[
      Tab(
        text:
            'Tôi nhận${_received == null ? '' : ' (${_openReceived.length})'}',
      ),
      // Order agreed for the Overlord home: Tôi nhận / Chờ duyệt / Tôi giao.
      if (_gives)
        Tab(
          text:
              'Chờ duyệt${_given == null ? '' : ' (${_toReview.fold<int>(0, (s, t) => s + _waiting(t))})'}',
        ),
      if (_gives)
        Tab(
          text: 'Tôi giao${_given == null ? '' : ' (${_activeGiven.length})'}',
        ),
    ];
    return DefaultTabController(
      length: tabs.length,
      initialIndex: widget.initialTab.clamp(0, tabs.length - 1),
      child: Scaffold(
        backgroundColor: vd.bg,
        // "+ Giao việc" is also here, for those who can give work.
        floatingActionButton: AppSession.instance.canAssign
            ? FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GiveTaskScreen()),
                  );
                  _load();
                },
                icon: const Icon(Icons.add),
                label: const Text('Giao việc'),
              )
            : null,
        appBar: AppBar(
          title: const Text('Việc của tôi'),
          bottom: TabBar(
            tabs: tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: vd.onHeader,
            unselectedLabelColor: vd.onHeader.withValues(alpha: 0.7),
            indicatorColor: vd.onHeader,
          ),
        ),
        body: TabBarView(
          children: [
            _receivedTab(),
            if (_gives) _reviewTab(),
            if (_gives) _givenTab(),
          ],
        ),
      ),
    );
  }

  // Lets the extensions in this library's parts call setState.
  void _set(VoidCallback f) => setState(f);
}
