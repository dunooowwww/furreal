import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Event Analytics MVP (PRD §7, M6). Nilai parameter selalu string/angka.
abstract interface class Analytics {
  /// [encounter]: `new` (hewan baru) atau `again` (ketemu lagi).
  /// [timing]: `on_time` atau `late` menurut jam HP.
  Future<void> catchCreated({
    required String encounter,
    required String timing,
  });

  /// [type]: `like` atau `laugh`.
  Future<void> reactionAdded({required String type});

  /// [method]: `invite_code` (gabung) atau `create` (bikin circle baru).
  Future<void> circleJoined({required String method});
}

class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  Future<void> catchCreated({
    required String encounter,
    required String timing,
  }) async {}

  @override
  Future<void> reactionAdded({required String type}) async {}

  @override
  Future<void> circleJoined({required String method}) async {}
}

class FirebaseAnalyticsTracker implements Analytics {
  FirebaseAnalyticsTracker(this._analytics);

  final FirebaseAnalytics _analytics;

  Future<void> _log(String name, Map<String, Object> parameters) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e) {
      // Metrik tidak boleh mengganggu alur user.
      debugPrint('analytics $name gagal: $e');
    }
  }

  @override
  Future<void> catchCreated({
    required String encounter,
    required String timing,
  }) => _log('catch_created', {'encounter': encounter, 'timing': timing});

  @override
  Future<void> reactionAdded({required String type}) =>
      _log('reaction_added', {'type': type});

  @override
  Future<void> circleJoined({required String method}) =>
      _log('circle_joined', {'method': method});
}

/// Di-override di `main.dart` kalau Firebase tersedia, dan di test.
final analyticsProvider = Provider<Analytics>((ref) => const NoopAnalytics());
