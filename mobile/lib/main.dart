import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const BusTrackApp());
}

class BusTrackApp extends StatelessWidget {
  const BusTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'BusTrack University',
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
