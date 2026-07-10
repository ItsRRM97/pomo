import 'package:flutter/widgets.dart';
import 'package:pomo/app/app.dart';
import 'package:pomo/bootstrap.dart';
import 'package:pomo/desktop/overlay_app.dart';
import 'package:pomo/singletons/prefs.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (args.firstOrNull == 'multi_window') {
    await Prefs().init();
    runApp(const OverlayApp());
    return;
  }

  await bootstrap(() => const App());
}
