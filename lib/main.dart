import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'pages/profile/profile_store.dart';
import 'services/custom_mode_store.dart';
import 'services/alarm_notification_service.dart';
import 'services/daily_progress_sync_service.dart';
import 'services/escore_reset_service.dart';
import 'services/firestore_remote_sync.dart';
import 'services/remote_sync.dart';
import 'services/sleep_schedule_store.dart';
import 'services/theme_mode_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Color(0xFF07090D),
      systemNavigationBarDividerColor: Color(0xFF07090D),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // sqflite only ships native bindings for mobile; desktop uses FFI.
  // Skip on web where dart:io is not available.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await dotenv.load();
  await Future.wait(<Future<void>>[
    ProfileStore.instance.init(),
    SleepScheduleStore.instance.init(),
    CustomModeStore.instance.init(),
    ThemeModeStore.instance.init(),
  ]);
  unawaited(_initFirebaseSync());
  unawaited(_initBackgroundServices());
  runApp(const EnergyHealthApp());
}

Future<void> _initFirebaseSync() async {
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    RemoteSync.use(FirestoreRemoteSync());
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      unawaited(
        EscoreResetService.instance
            .checkForRemoteReset()
            .then((_) => DailyProgressSyncService.instance.syncToday()),
      );
    });
    await EscoreResetService.instance.checkForRemoteReset();
    DailyProgressSyncService.instance.startBackgroundTopScoreRefresh();
  } catch (_) {}
}

Future<void> _initBackgroundServices() async {
  try {
    await AlarmNotificationService.instance.init();
  } catch (_) {}
}
