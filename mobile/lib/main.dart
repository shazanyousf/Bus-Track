import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await NotificationService.instance.initialize();
  runApp(const BusTrackApp());
}

class BusTrackApp extends StatelessWidget {
  const BusTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(onSessionRevoked: () async {
          final navigator = navigatorKey.currentState;
          if (navigator == null) return;
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen(
              initialMessage: 'Your account was signed in on another device.',
            )),
            (_) => false,
          );
        })),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'BusTrack School',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFFF6B35),
            background: const Color(0xFF0F0F1A),
            surface: const Color(0xFF16213E),
          ),
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
          fontFamily: 'Helvetica Neue',
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
