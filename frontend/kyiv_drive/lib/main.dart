import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:kyiv_drive/services/notification_service.dart';
import 'core/globals.dart';
import 'core/router.dart';
import 'services/user_session.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  NotificationService.init(globalNavigatorKey);

  UserSession().init();
  runApp(const KyivDriveApp());
}

class KyivDriveApp extends StatelessWidget {
  const KyivDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      title: 'KyivDrive',

      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('uk'), Locale('ru')],
    );
  }
}
