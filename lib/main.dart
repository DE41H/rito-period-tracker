import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:buritto/app.dart';
import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/logic/security.dart';
import 'package:buritto/providers/home_provider.dart';
import 'package:buritto/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveDatabase().init();
  await BiometricAuth().lock();

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

