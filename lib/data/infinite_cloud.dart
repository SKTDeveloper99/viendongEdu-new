import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/infinite/quest.dart';

/// What Firestore said about a claim.
enum CloudVerdict {
  /// Server accepted the claim (rules checked code and dates).
  saved,

  /// No network: Firestore queued the write and will send it later.
  queued,

  /// Server rules refused it (wrong code, outside the dates).
  refused,

  /// Firebase is not set up or not reachable; progress stays on the phone.
  off,
}

/// Game progress in Firestore, signed in anonymously.
///
/// Path: `infinite_players/{uid}/profiles/{profile}/claims/{questId}`.
/// [profile] is a random per-phone key for each MSSV, so two students on
/// one phone stay apart and Firebase never stores an MSSV or name.
/// Every call is best effort with short timeouts: the game never waits on
/// Firebase and never fails because of it.
class InfiniteCloud {
  InfiniteCloud({FirebaseAuth? auth, FirebaseFirestore? db})
    : _authOverride = auth,
      _dbOverride = db;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _dbOverride;
  DocumentReference<Map<String, dynamic>>? _profile;

  static const _signInTimeout = Duration(seconds: 6);
  static const _writeTimeout = Duration(seconds: 6);

  /// Signs in and resolves the profile document; null when unavailable.
  Future<DocumentReference<Map<String, dynamic>>?> _ref(String who) async {
    if (_profile != null) return _profile;
    try {
      final auth = _authOverride ?? FirebaseAuth.instance;
      final db = _dbOverride ?? FirebaseFirestore.instance;
      final user =
          auth.currentUser ??
          (await auth.signInAnonymously().timeout(_signInTimeout)).user;
      if (user == null) return null;
      return _profile = db
          .collection('infinite_players')
          .doc(user.uid)
          .collection('profiles')
          .doc(await _profileKey(who));
    } catch (e) {
      debugPrint('[Infinite] cloud off: $e');
      return null;
    }
  }

  static Future<String> _profileKey(String who) async {
    final p = await SharedPreferences.getInstance();
    var salt = p.getString('infinite.salt');
    if (salt == null) {
      final r = Random.secure();
      salt = base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
      await p.setString('infinite.salt', salt);
    }
    return sha256
        .convert(utf8.encode('$salt:$who'))
        .toString()
        .substring(0, 32);
  }

  /// Quest ids claimed in the cloud (cache first when offline).
  Future<Set<String>> claimed(String who) async {
    final ref = await _ref(who);
    if (ref == null) return {};
    try {
      final snap = await ref.collection('claims').get().timeout(_writeTimeout);
      return snap.docs.map((d) => d.id).toSet();
    } catch (e) {
      debugPrint('[Infinite] cloud read failed: $e');
      return {};
    }
  }

  Future<CloudVerdict> claim(
    String who,
    Quest q, {
    required String code,
    double? lat,
    double? lng,
    double? accuracyM,
  }) async {
    final ref = await _ref(who);
    if (ref == null) return CloudVerdict.off;
    final write = ref.collection('claims').doc(q.id).set({
      'at': FieldValue.serverTimestamp(),
      if (q.needsCode) 'code': normalizeCode(code),
      'lat': ?lat,
      'lng': ?lng,
      'acc': ?accuracyM,
    });
    try {
      await write.timeout(_writeTimeout);
      return CloudVerdict.saved;
    } on TimeoutException {
      // Firestore keeps the write and sends it when the phone is online.
      return CloudVerdict.queued;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Already claimed elsewhere also lands here (claims are create-once).
        final existing = await ref
            .collection('claims')
            .doc(q.id)
            .get()
            .then((d) => d.exists, onError: (_) => false);
        return existing ? CloudVerdict.saved : CloudVerdict.refused;
      }
      debugPrint('[Infinite] cloud write failed: ${e.code}');
      return CloudVerdict.off;
    } catch (e) {
      debugPrint('[Infinite] cloud write failed: $e');
      return CloudVerdict.off;
    }
  }

  /// Mirrors the equipped frame and title; failures are ignored.
  Future<void> equip(String who, String? frame, String? title) async {
    final ref = await _ref(who);
    if (ref == null) return;
    unawaited(
      ref
          .set({
            'frame': frame,
            'title': title,
            'at': FieldValue.serverTimestamp(),
          })
          .catchError((Object e) => debugPrint('[Infinite] equip sync: $e')),
    );
  }
}
