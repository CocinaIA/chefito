import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'ingredient_recognizer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ChefitoApp());
}

class ChefitoApp extends StatelessWidget {
  const ChefitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      debugShowCheckedModeBanner: false,
      title: 'Chefito',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomeScreen(),
      routes:  {
        '/reconocer': (context) => const IngredientRecognizer(),
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
      appBar: AppBar(title: const Text("Chefito 🧑‍🍳")),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/reconocer');
          },
          icon: const Icon(Icons.camera_alt),
          label: const Text("Reconocer ingrediente"),
        ),
      ),
    );
  }
}
