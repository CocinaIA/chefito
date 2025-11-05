import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'screens/web_landing_screen.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChefitoApp());
}

class ChefitoApp extends StatelessWidget {
  const ChefitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        primaryColor: Colors.green[600],
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      // Determinar la pantalla inicial basado en la plataforma
      home: const WebLandingScreen(),
    );
  }
}