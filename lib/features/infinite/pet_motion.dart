import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

/// Bounded pet interactions; idle pets never keep a ticker running.
class PetMotion extends ChangeNotifier {
  PetMotion({required TickerProvider vsync})
    : _squash = AnimationController(vsync: vsync, duration: squashDuration),
      _dizzy = AnimationController(vsync: vsync, duration: dizzyCycle) {
    _squash.addListener(notifyListeners);
    _dizzy.addListener(notifyListeners);
  }

  static const tapsForDizzy = 5;
  static const tapWindow = Duration(seconds: 1);
  static const squashDuration = Duration(milliseconds: 280);
  static const dizzyDuration = Duration(seconds: 3);
  static const dizzyCycle = Duration(milliseconds: 800);

  static final _stretch = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.8,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.8,
        end: 1.1,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.1,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
  ]);

  final AnimationController _squash;
  final AnimationController _dizzy;
  final _tapExpirations = <Timer>[];
  Timer? _recovery;
  bool _isDizzy = false;
  bool _reduced = false;

  bool get isDizzy => _isDizzy;
  double get scaleY =>
      _reduced || _isDizzy ? 1 : _stretch.transform(_squash.value);
  double get scaleX => 2 - scaleY;
  double get wobble =>
      _reduced ? 0 : math.sin(_dizzy.value * math.pi * 4) * 0.1;
  double get starAngle => _reduced ? 0 : _dizzy.value * math.pi * 2;

  void setReduced(bool reduced) {
    if (_reduced == reduced) return;
    _reduced = reduced;
    _squash.reset();
    _dizzy.reset();
    if (_isDizzy && !reduced) _dizzy.repeat();
  }

  void tap() {
    // Further taps cannot prolong dizziness or queue another reaction.
    if (_isDizzy) return;
    late final Timer expiration;
    expiration = Timer(tapWindow, () => _tapExpirations.remove(expiration));
    _tapExpirations.add(expiration);
    if (_tapExpirations.length >= tapsForDizzy) {
      _clearTaps();
      _isDizzy = true;
      _squash.reset();
      if (!_reduced) _dizzy.repeat();
      // Recovery uses wall time even when motion is disabled or tickers pause.
      _recovery = Timer(dizzyDuration, reset);
      notifyListeners();
    } else if (!_reduced) {
      _squash.forward(from: 0);
    }
  }

  void _clearTaps() {
    for (final timer in _tapExpirations) {
      timer.cancel();
    }
    _tapExpirations.clear();
  }

  /// Also used when the student switches companion.
  void reset() {
    _clearTaps();
    _recovery?.cancel();
    _recovery = null;
    _isDizzy = false;
    _squash.reset();
    _dizzy.reset();
    notifyListeners();
  }

  @override
  void dispose() {
    _clearTaps();
    _recovery?.cancel();
    _squash.dispose();
    _dizzy.dispose();
    super.dispose();
  }
}
