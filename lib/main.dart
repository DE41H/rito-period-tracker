import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:buritto/pages/home.dart';
import 'package:buritto/providers/home_provider.dart';
import 'package:buritto/providers/settings_provider.dart';
import 'package:buritto/hive/hive_database.dart';
import 'package:buritto/widgets/rectangular_thumb_slider.dart';
import 'package:buritto/logic/security.dart';

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
      child: const MyApp(),
    )
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() {
    return _MyAppState();
  }
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      BiometricAuth().lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Shifa-Rame',
        sliderTheme: SliderThemeData(
          activeTrackColor: Colors.black,
          inactiveTrackColor: Colors.grey,
          trackHeight: 2,
          thumbColor: Colors.black,
          thumbShape: RectangularThumbSlider(),
          showValueIndicator: ShowValueIndicator.never,
          activeTickMarkColor: Colors.transparent,
          inactiveTickMarkColor: Colors.transparent,
        )
      ),
      home: const HomePage(),
    );
  }
}
