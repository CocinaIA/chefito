import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  // Ensure we have a user for Firestore rules (owner-only writes)
  // If the provider isn't enabled yet in Firebase Console, don't crash the app.
  try {
    await FirebaseAuth.instance.signInAnonymously();
    debugPrint('✅ Signed in anonymously as: ${FirebaseAuth.instance.currentUser?.uid}');
  } on FirebaseAuthException catch (e) {
    debugPrint('⚠️ Anonymous sign-in failed (FirebaseAuthException): ${e.code} ${e.message}');
  } catch (e) {
    debugPrint('⚠️ Anonymous sign-in failed: $e');
  }
  
  
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerController;
  late Animation<double> _headerOpacity;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _headerOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
    );
    _headerController.forward();
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Header Section
              FadeTransition(
                opacity: _headerOpacity,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primary,
                        AppTheme.primary.withOpacity(0.85),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo y título
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text('🍳', style: TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LetMeCook',
                                  style: Theme.of(context)
                                      .textTheme
                                      .displaySmall
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Tu asistente culinario',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Descripción inspiradora
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              '✨',
                              style: TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Transforma ingredientes en recetas deliciosas',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main Actions Grid
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comienza aquí',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    // Grid 2x2
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _PremiumActionCard(
                          icon: '📸',
                          label: 'Reconocer\ningrediente',
                          isPrimary: true,
                          onTap: () => Navigator.pushNamed(context, '/reconocer'),
                        ),
                        _PremiumActionCard(
                          icon: '🧾',
                          label: 'Escanear\nticket',
                          onTap: () => Navigator.pushNamed(context, '/ticket'),
                        ),
                        _PremiumActionCard(
                          icon: '🗂️',
                          label: 'Mi\nalacena',
                          onTap: () => Navigator.pushNamed(context, '/pantry'),
                        ),
                        _PremiumActionCard(
                          icon: '👨‍🍳',
                          label: 'Recetas\nsugeridas',
                          isPrimary: true,
                          onTap: () => Navigator.pushNamed(context, '/recipes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Features Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Características',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.foreground,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _FeatureRow(
                      icon: Icons.camera_alt_outlined,
                      title: 'Reconocimiento Visual',
                      description: 'Identifica ingredientes con tu cámara',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.receipt_long_outlined,
                      title: 'Escaneo de Tickets',
                      description: 'Extrae ingredientes automáticamente',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.auto_awesome_outlined,
                      title: 'IA Generativa',
                      description: 'Crea recetas personalizadas con IA',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.restaurant_outlined,
                      title: 'Catálogo de Recetas',
                      description: 'Explora miles de opciones culinarias',
                    ),
                  ],
                ),
              ),

              // Call to Action
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryLight.withOpacity(0.3),
                        AppTheme.primaryLight.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '🚀 ¿Listo para cocinar?',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppTheme.foreground,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Comienza agregando tus ingredientes disponibles',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumActionCard extends StatefulWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _PremiumActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<_PremiumActionCard> createState() => _PremiumActionCardState();
}

class _PremiumActionCardState extends State<_PremiumActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
    _elevationAnimation = Tween<double>(begin: 8, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown() {
    _controller.forward();
  }

  void _onTapUp() {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _onTapDown(),
      onTapUp: (_) => _onTapUp(),
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedBuilder(
          animation: _elevationAnimation,
          builder: (context, child) {
            return Card(
              elevation: _elevationAnimation.value,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: widget.isPrimary
                  ? AppTheme.primary
                  : Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: !widget.isPrimary
                      ? Border.all(
                          color: AppTheme.primaryLight.withOpacity(0.4),
                          width: 1.5,
                        )
                      : null,
                ),
                child: InkWell(
                  onTap: () {}, // Ya manejado por GestureDetector
                  borderRadius: BorderRadius.circular(20),
                  splashColor: widget.isPrimary
                      ? Colors.white.withOpacity(0.2)
                      : AppTheme.primary.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.icon,
                          style: const TextStyle(fontSize: 40),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.isPrimary
                                ? Colors.white
                                : AppTheme.foreground,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryLight.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.foreground,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
