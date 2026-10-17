import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/prefs.dart';
import 'core/push.dart';
import 'screens/splash_screen.dart';
import 'screens/web_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await Prefs.init();
  await PushService.init();
  runApp(const RFBuilderApp());
}

class RFBuilderApp extends StatefulWidget {
  const RFBuilderApp({super.key});
  @override
  State<RFBuilderApp> createState() => _RFBuilderAppState();
}

class _RFBuilderAppState extends State<RFBuilderApp> {
  late bool _showSplash = !Prefs.skipSplash;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RFBuilder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF07070E)),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: _showSplash
            ? SplashScreen(key: const ValueKey('splash'), onDone: () => setState(() => _showSplash = false))
            : const WebShell(key: ValueKey('web')),
      ),
    );
  }
}
