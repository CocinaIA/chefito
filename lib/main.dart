import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'ingredient_recognizer.dart';
import 'screens/receipt_scanner_screen.dart';
import 'screens/pantry_screen.dart';
import 'screens/recipes_screen.dart';
import 'config.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  debugPrint('🔥 Firebase initialized');
  debugPrint('🔥 useFirestoreEmulator: ${AppConfig.useFirestoreEmulator}');
  // Ensure the app is authenticated for Firestore access during development.
  // This signs in anonymously if there is no user yet so Firestore rules
  // that require authentication will pass. It's safe for local/dev usage.
  try {
    if (FirebaseAuth.instance.currentUser == null) {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      debugPrint('🔑 Signed in anonymously: ${cred.user?.uid}');
    } else {
      debugPrint('🔑 Already signed in: ${FirebaseAuth.instance.currentUser?.uid}');
    }
  } catch (e) {
    debugPrint('❌ Anonymous sign-in failed: $e');
  }
  
  if (AppConfig.useFirestoreEmulator) {
    debugPrint('🔥 Connecting to Firestore emulator at ${AppConfig.firestoreEmulatorHost}:${AppConfig.firestoreEmulatorPort}');
    FirebaseFirestore.instance.useFirestoreEmulator(
      AppConfig.firestoreEmulatorHost,
      AppConfig.firestoreEmulatorPort,
    );
    debugPrint('✅ Firestore emulator configured');
  }
  runApp(const ChefitoApp());
}

class ChefitoApp extends StatelessWidget {
  const ChefitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chefito',
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
      routes: {
        '/reconocer': (context) => const IngredientRecognizer(),
        '/ticket': (context) => const ReceiptScannerScreen(),
        '/pantry': (context) => const PantryScreen(),
        '/recipes': (context) => const RecipesScreen(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chefito')),
      body: const Center(
        child: Text('¡Firebase conectado correctamente! 🍳'),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "LetMeCook",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/reconocer');
              },
              icon: const Icon(Icons.camera_alt),
              label: const Text("Reconocer ingrediente"),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/ticket');
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text("Escanear ticket"),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/pantry');
              },
              icon: const Icon(Icons.kitchen),
              label: const Text("Mi alacena"),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/recipes');
              },
              icon: const Icon(Icons.restaurant_menu),
              label: const Text("Ver recetas sugeridas"),
            ),
          ],
        ),
      ),
    );
  }
}
