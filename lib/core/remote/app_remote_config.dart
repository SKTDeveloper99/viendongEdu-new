import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../../features/infinite/quest.dart';

/// Firebase Remote Config, edited by `firebase deploy --only remoteconfig`
/// from `remoteconfig.template.json`. Every read falls back to the built-in
/// default, so a missing Firebase (tests, offline first launch) changes
/// nothing.
class AppRemoteConfig {
  static const questsKey = 'infinite_quests';
  static const minPrefixKey = 'lantern_min_prefix';
  static const defaultMinPrefix = 25;

  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(minutes: 10),
        ),
      );
      await rc.setDefaults(const {
        questsKey: defaultQuestsJson,
        minPrefixKey: defaultMinPrefix,
      });
      unawaited(
        rc.fetchAndActivate().catchError((Object e) {
          debugPrint('[RemoteConfig] fetch failed: $e');
          return false;
        }),
      );
    } catch (e) {
      debugPrint('[RemoteConfig] init failed: $e');
    }
  }

  static String get questsJson {
    try {
      final v = FirebaseRemoteConfig.instance.getString(questsKey);
      return v.isEmpty ? defaultQuestsJson : v;
    } catch (_) {
      return defaultQuestsJson;
    }
  }

  static int get minPrefix {
    try {
      final v = FirebaseRemoteConfig.instance.getInt(minPrefixKey);
      return v == 0 ? defaultMinPrefix : v;
    } catch (_) {
      return defaultMinPrefix;
    }
  }
}
