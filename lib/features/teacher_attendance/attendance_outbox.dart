import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../data/teacher_attendance_repository.dart';
import '../../services/app_session.dart';
import '../../services/ems_api_service.dart';
import 'attendance_sender.dart';
import 'draft_merge.dart';

/// App-wide drainer of queued teacher attendance drafts. Sends them without
/// the roster screen: on resume, when connectivity returns, and every
/// [interval] while in the foreground. Sequential, one draft at a time.
class AttendanceOutbox with WidgetsBindingObserver {
  AttendanceOutbox({
    this.repository = const TeacherAttendanceRepository(),
    this.interval = const Duration(seconds: 30),
    bool Function()? isEligible,
    Stream<List<ConnectivityResult>>? connectivity,
  }) : _isEligible = isEligible ?? (() => AppSession.instance.isGiangVien),
       _connectivity = connectivity;

  static final AttendanceOutbox instance = AttendanceOutbox();

  final TeacherAttendanceRepository repository;
  final Duration interval;
  final bool Function() _isEligible;
  final Stream<List<ConnectivityResult>>? _connectivity;

  /// Number of queued drafts of the current account ("N chờ gửi").
  final ValueNotifier<int> pendingCount = ValueNotifier(0);
  final _finished = StreamController<String>.broadcast();

  /// draftKeys whose queue state changed (sent, unqueued): open screens reload.
  Stream<String> get finished => _finished.stream;

  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _started = false;
  bool _draining = false;
  int _generation = 0;

  /// Idempotent. Call when a teacher session is showing.
  void start() {
    if (_started || !_isEligible()) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    AppSession.clearHooks.add(stop);
    _connSub = (_connectivity ?? Connectivity().onConnectivityChanged).listen((
      r,
    ) {
      if (r.any((c) => c != ConnectivityResult.none)) unawaited(drain());
    });
    _startTimer();
    unawaited(drain());
  }

  /// Logout: cancel everything and forget the count.
  void stop() {
    _generation++;
    _started = false;
    _timer?.cancel();
    _timer = null;
    _connSub?.cancel();
    _connSub = null;
    WidgetsBinding.instance.removeObserver(this);
    AppSession.clearHooks.remove(stop);
    pendingCount.value = 0;
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(drain()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(drain());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Recount without sending (after the screen queues or unqueues a draft).
  Future<void> refreshCount() async {
    if (!_isEligible()) {
      pendingCount.value = 0;
      return;
    }
    final all = await repository.listDrafts();
    pendingCount.value = all.where((d) => d.draft.queued).length;
  }

  /// One sequential pass over the queue. Safe to call at any time.
  Future<void> drain() async {
    if (_draining || !_isEligible()) return;
    _draining = true;
    final gen = _generation;
    try {
      final queued = (await repository.listDrafts())
          .where((d) => d.draft.queued)
          .toList();
      if (gen != _generation) return;
      pendingCount.value = queued.length;
      for (final q in queued) {
        if (gen != _generation) return;
        if (q.draft.session == null) continue; // old draft: screen only
        if (!AttendanceSendLock.tryAcquire(q.draftKey)) continue;
        try {
          if (await _sendOne(q.draftKey, gen) && !_finished.isClosed) {
            _finished.add(q.draftKey);
          }
        } finally {
          AttendanceSendLock.release(q.draftKey);
        }
      }
      if (gen == _generation) await refreshCount();
    } catch (_) {
      // Storage/network hiccup: next tick retries.
    } finally {
      _draining = false;
    }
  }

  /// True when the draft's queue state changed (sent or held for review).
  Future<bool> _sendOne(String key, int gen) async {
    // The screen may have changed it since listing.
    final draft = await repository.loadDraft(key);
    final session = draft?.session;
    if (draft == null || !draft.queued || session == null) return false;
    final EmsRoster roster;
    try {
      roster = await repository.roster(session);
    } catch (_) {
      return false; // offline / server down: stay queued
    }
    if (gen != _generation) return false;
    final merged = mergeDraftWithRoster(draft, roster.students);
    final keep = merged.draftToSave;
    if (keep != null) {
      await repository.saveDraft(
        key,
        keep.marks,
        keep.notes,
        queued: false,
        students: keep.students,
        session: session,
      );
      return true;
    }
    try {
      await sendAndVerify(
        repository,
        session,
        merged.marks,
        merged.notes,
        roster.students,
      );
      // The teacher may have edited the open screen while we were sending;
      // never wipe that newer draft.
      final now = await repository.loadDraft(key);
      if (now == null ||
          (mapEquals(now.marks, draft.marks) &&
              mapEquals(now.notes, draft.notes))) {
        await repository.clearDraft(key);
      }
      return true;
    } on EmsPunchConflict {
      await _unqueue(key, merged, roster, session);
      return true;
    } on EmsException catch (e) {
      if (!isClientRefusal(e)) return false;
      await _unqueue(key, merged, roster, session);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _unqueue(
    String key,
    DraftMergeResult merged,
    EmsRoster roster,
    EmsSession session,
  ) => repository.saveDraft(
    key,
    merged.marks,
    merged.notes,
    queued: false,
    students: roster.students,
    session: session,
  );
}
