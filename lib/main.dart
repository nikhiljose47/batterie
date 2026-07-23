import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app.dart';
import 'pages/profile/profile_store.dart';
import 'services/sleep_schedule_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // sqflite only ships native bindings for mobile; desktop uses FFI.
  // Skip on web where dart:io is not available.
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await dotenv.load();
  await ProfileStore.instance.init();
  await SleepScheduleStore.instance.init();
  runApp(const EnergyHealthApp());
}
