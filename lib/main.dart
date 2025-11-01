import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'ingredient_recognizer.dart';
import 'screens/receipt_scanner_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/web_landing_screen.dart';
import 'services/database_helper.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializar base de datos
  try {
    await DatabaseHelper.instance.database;
    debugPrint('✅ SQLite database initialized');
  } catch (e) {
    debugPrint('❌ Error initializing database: $e');
  }
  
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
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      // Determinar la pantalla inicial basado en la plataforma
      home: kIsWeb ? const WebLandingScreen() : const HomeScreen(),
      routes: {
        '/home': (context) => const HomeScreen(),
        '/reconocer': (context) => const IngredientRecognizer(),
        '/ticket': (context) => const ReceiptScannerScreen(),
        '/pantry': (context) => const PantryScreen(),
        '/web': (context) => const WebLandingScreen(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("${AppConfig.appName} 🧑‍🍳"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 32),
              Text(
                AppConfig.landingPageTitle,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppConfig.landingPageDescription,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              _buildMenuButton(
                context,
                icon: Icons.camera_alt,
                label: "Reconocer ingrediente",
                route: '/reconocer',
                color: Colors.blue,
              ),
              const SizedBox(height: 16),
              _buildMenuButton(
                context,
                icon: Icons.receipt_long,
                label: "Escanear ticket",
                route: '/ticket',
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              _buildMenuButton(
                context,
                icon: Icons.kitchen,
                label: "Mi alacena",
                route: '/pantry',
                color: Colors.green,
              ),
              if (kIsWeb) ...[
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/web'),
                  child: const Text('Ver página web optimizada'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pushNamed(context, route),
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}