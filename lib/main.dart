import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:provider/provider.dart';

import './pages/home.dart';
import './providers/home_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/rectangular_thumb_slider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openLazyBox('messages');

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
