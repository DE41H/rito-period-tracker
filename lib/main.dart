import 'package:buritto/app.dart';
import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/filter.dart';
import 'package:buritto/logic/network.dart';
import 'package:buritto/logic/security.dart';
import 'package:buritto/providers/home_provider.dart';
import 'package:buritto/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:worker_manager/worker_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await (
    HiveDatabase().init(),
    workerManager.init(isolatesCount: 2),
    BiometricAuth().init(),
  ).wait;
  await (
    BiometricAuth().lock(),
    KalmanFilter().init(),
    BayesNetwork().init(),
  ).wait;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: const App(),
    )
  );
}

