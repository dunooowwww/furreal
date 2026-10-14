import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../features/notifications/data/push_messaging.dart';
import '../features/notifications/state/notification_providers.dart';
import '../shared/analytics.dart';

/// Nyalakan Firebase (notifikasi, Analytics, Crashlytics) kalau
/// `google-services.json` terpasang. Tanpa itu, app jalan tanpa ketiganya.
/// Mengembalikan override provider untuk [ProviderScope].
Future<List<Override>> initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase tidak aktif (google-services.json belum ada?): $e');
    return const [];
  }

  final crashlytics = FirebaseCrashlytics.instance;
  // Crash saat development tidak dikirim, supaya data uji tetap bersih.
  await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
  FlutterError.onError = crashlytics.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    crashlytics.recordError(error, stack, fatal: true);
    return true;
  };

  return [
    pushMessagingProvider.overrideWithValue(
      FirebasePushMessaging(FirebaseMessaging.instance),
    ),
    analyticsProvider.overrideWithValue(
      FirebaseAnalyticsTracker(FirebaseAnalytics.instance),
    ),
  ];
}
