import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'services/prefs_store.dart';
import 'theme.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs: PrefsStore(prefs));
  runApp(NewDroidApp(state: state));
}

class NewDroidApp extends StatefulWidget {
  const NewDroidApp({super.key, required this.state});

  final AppState state;

  @override
  State<NewDroidApp> createState() => _NewDroidAppState();
}

class _NewDroidAppState extends State<NewDroidApp> {
  @override
  void initState() {
    super.initState();
    widget.state.init();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AppState>.value(
      value: widget.state,
      child: Builder(
        builder: (context) {
          final state = context.watch<AppState>();
          return MaterialApp(
            title: 'NewDroid',
            debugShowCheckedModeBanner: false,
            theme: ndLightTheme(),
            darkTheme: ndDarkTheme(),
            themeMode: state.themeMode,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
