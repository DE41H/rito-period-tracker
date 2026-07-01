import 'package:buritto/app.dart';
import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/intent.dart';
import 'package:buritto/logic/network.dart';
import 'package:buritto/logic/security.dart';
import 'package:buritto/providers/calendar_provider.dart';
import 'package:buritto/providers/home_provider.dart';
import 'package:buritto/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worker_manager/worker_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await (
    (workerManager.init(isolatesCount: 2), HiveDatabase().init()).wait.then((_) => (KalmanFilter().init(), BayesNetwork().init()).wait),
    BiometricAuth().init().then((_) => BiometricAuth().lock()),
    IntentJudge().init(),
  ).wait;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider())
      ],
      child: const App(),
    )
  );
}

