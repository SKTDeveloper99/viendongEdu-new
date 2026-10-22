import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config, edited by `firebase deploy --only remoteconfig`
/// from `remoteconfig.template.json`. Every read falls back to the built-in
/// default, so a missing Firebase (tests, offline first launch) changes
/// nothing.
class AppRemoteConfig {
  /// Builds up to 6.0.6+6 read [questsKey]; newer builds read [bookKey].
  /// Keeping both lets old phones and new phones play side by side.
  static const questsKey = 'infinite_quests';
  static const bookKey = 'infinite_book_v2';
  static const defaultMinPrefix = 0;

  /// Bumps whenever a new config is activated, so open screens can reload.
  static final changes = ValueNotifier<int>(0);
  static StreamSubscription<RemoteConfigUpdate>? _live;

  static const minPrefixKey = 'lantern_min_prefix';

  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(minutes: 10),
        ),
      );
      // No default for [bookKey]: empty means "not published", so the game
      // falls back to the phone's last good copy before the built-in one.
      await rc.setDefaults(const {minPrefixKey: defaultMinPrefix});
      unawaited(
        rc.fetchAndActivate().then((_) => changes.value++).catchError((
          Object e,
        ) {
          debugPrint('[RemoteConfig] fetch failed: $e');
          return 0;
        }),
      );
      // Real-time updates: a console publish reaches open apps in seconds.
      _live ??= rc.onConfigUpdated.listen((u) async {
        if (!u.updatedKeys.contains(bookKey) &&
            !u.updatedKeys.contains(minPrefixKey)) {
          return;
        }
        await rc.activate();
        changes.value++;
      }, onError: (Object e) => debugPrint('[RemoteConfig] live: $e'));
    } catch (e) {
      debugPrint('[RemoteConfig] init failed: $e');
    }
  }

  /// The published game book, or '' when there is none.
  static String get bookJson {
    try {
      return FirebaseRemoteConfig.instance.getString(bookKey);
    } catch (_) {
      return '';
    }
  }

  static int get minPrefix {
    try {
      return FirebaseRemoteConfig.instance.getInt(minPrefixKey);
    } catch (_) {
      return defaultMinPrefix;
    }
  }
}
