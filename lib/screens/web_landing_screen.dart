import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../config.dart';
import '../services/chatgpt_service.dart';
import '../services/inventory_service.dart';
import '../models/recipe.dart';
import 'dart:html' as html;

class WebLandingScreen extends StatefulWidget {
  const WebLandingScreen({super.key});

  @override
  State<WebLandingScreen> createState() => _WebLandingScreenState();
}

class _WebLandingScreenState extends State<WebLandingScreen> with TickerProviderStateMixin {
  final ChatGPTService _chatGPTService = ChatGPTService();
  final InventoryService _inventoryService = InventoryService();
  
  bool _isLoadingRecipe = false;
  Recipe? _currentRecipe;
  bool _showInventory = false;
  bool _showRecipeModal = false;
  
  late AnimationController _heroAnimationController;
  late AnimationController _featuresAnimationController;
  late Animation<double> _heroFadeAnimation;
  late Animation<Offset> _heroSlideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _heroAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _featuresAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _heroFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeOut,
    ));

    _heroSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroAnimationController,
      curve: Curves.easeOut,
    ));

    _heroAnimationController.forward();
    
    Future.delayed(const Duration(milliseconds: 600), () {
      _featuresAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _heroAnimationController.dispose();
    _featuresAnimationController.dispose();
    super.dispose();
  }

  Future<void> _generateRecipe() async {
    setState(() {
      _isLoadingRecipe = true;
    });

    try {
      final recipeData = await _chatGPTService.getRecipeSuggestions(_inventoryService.ingredients);
      final recipe = Recipe.fromJson(recipeData);
      
      setState(() {
        _currentRecipe = recipe;
        _isLoadingRecipe = false;
        _showRecipeModal = true;
      });
    } catch (e) {
      setState(() {
        _isLoadingRecipe = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar receta: $e'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  void _simulateReceiptScan() {
    final newIngredients = _inventoryService.simulateReceiptScan();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('¡Ticket escaneado! Se agregaron ${newIngredients.length} ingredientes'),
        backgroundColor: Colors.green[600],
        action: SnackBarAction(
          label: 'Ver inventario',
          onPressed: () => setState(() => _showInventory = true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildHeroSection(),
            _buildProblemsSection(),
            _buildHowItWorksSection(),
            _buildFeaturesSection(),
            _buildDemoSection(),
            _buildTestimonialsSection(),
            _buildCTASection(),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[400]!, Colors.green[600]!],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.restaurant_menu,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                AppConfig.appName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _scrollToSection('features'),
                child: const Text('Funciones'),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () => _scrollToSection('demo'),
                child: const Text('Demo'),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => _scrollToSection('cta'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text('Probar Gratis'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[50]!,
            Colors.yellow[50]!,
            Colors.white,
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _heroAnimationController,
        builder: (context, child) {
          return FadeTransition(
            opacity: _heroFadeAnimation,
            child: SlideTransition(
              position: _heroSlideAnimation,
              child: Column(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[400]!, Colors.green[600]!],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.kitchen,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Cocina con lo que ya compraste',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Escanea tu ticket de compra y recibe recetas personalizadas\ncon los ingredientes que tienes en casa',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _scrollToSection('demo'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Ver Demo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: () => _scrollToSection('features'),
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Cómo funciona'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green[600],
                          side: BorderSide(color: Colors.green[600]!),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProblemsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      child: Column(
        children: [
          Text(
            '¿Te suena familiar?',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildProblemCard(
                icon: Icons.shopping_cart,
                title: 'Compras sin planificar',
                description: 'Llegas del súper con ingredientes pero no sabes qué cocinar',
                color: Colors.red,
              ),
              _buildProblemCard(
                icon: Icons.access_time,
                title: 'Pierdes tiempo pensando',
                description: 'Gastas 20 minutos decidiendo qué preparar para cenar',
                color: Colors.orange,
              ),
              _buildProblemCard(
                icon: Icons.delete,
                title: 'Desperdicias comida',
                description: 'Los ingredientes se vencen antes de que los uses',
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProblemCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              size: 30,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorksSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.green[50]!,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            '¿Cómo funciona Chefito?',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'En 3 simples pasos tendrás recetas personalizadas',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStepCard(
                step: '1',
                icon: Icons.camera_alt,
                title: 'Escanea tu ticket',
                description: 'Toma una foto de tu factura de compra y nuestro OCR extraerá automáticamente los ingredientes',
                color: Colors.blue,
              ),
              _buildStepArrow(),
              _buildStepCard(
                step: '2',
                icon: Icons.inventory,
                title: 'Actualiza tu inventario',
                description: 'Los ingredientes se agregan automáticamente a tu despensa digital inteligente',
                color: Colors.green,
              ),
              _buildStepArrow(),
              _buildStepCard(
                step: '3',
                icon: Icons.auto_fix_high,
                title: 'Recibe recetas IA',
                description: 'ChatGPT analiza tu inventario y sugiere recetas deliciosas que puedes hacer ahora',
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required String step,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.8), color],
                  ),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 0,
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      step,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStepArrow() {
    return Icon(
      Icons.arrow_forward,
      size: 30,
      color: Colors.grey[400],
    );
  }

  Widget _buildFeaturesSection() {
    return Container(
      key: const Key('features'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      child: Column(
        children: [
          Text(
            'Funciones destacadas',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          AnimatedBuilder(
            animation: _featuresAnimationController,
            builder: (context, child) {
              return Wrap(
                spacing: 30,
                runSpacing: 30,
                children: [
                  _buildFeatureCard(
                    icon: Icons.document_scanner,
                    title: 'OCR Automático',
                    description: 'Reconocimiento óptico de caracteres para extraer ingredientes de tickets',
                    color: Colors.blue,
                  ),
                  _buildFeatureCard(
                    icon: Icons.smart_toy,
                    title: 'IA Conversacional',
                    description: 'ChatGPT analiza tu inventario y sugiere recetas personalizadas',
                    color: Colors.purple,
                  ),
                  _buildFeatureCard(
                    icon: Icons.inventory_2,
                    title: 'Inventario Inteligente',
                    description: 'Gestión automática de tu despensa con fechas de vencimiento',
                    color: Colors.green,
                  ),
                  _buildFeatureCard(
                    icon: Icons.restaurant,
                    title: 'Recetas Adaptativas',
                    description: 'Sugerencias que se adaptan a lo que tienes disponible',
                    color: Colors.orange,
                  ),
                  _buildFeatureCard(
                    icon: Icons.shopping_list,
                    title: 'Lista de Compras',
                    description: 'Genera listas inteligentes basadas en tus recetas favoritas',
                    color: Colors.red,
                  ),
                  _buildFeatureCard(
                    icon: Icons.video_library,
                    title: 'Videos Paso a Paso',
                    description: 'Tutoriales en video para cada receta sugerida',
                    color: Colors.teal,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDemoSection() {
    return Container(
      key: const Key('demo'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[50]!,
            Colors.yellow[50]!,
          ],
        ),
      ),
      child: Column(
        children: [
          Text(
            'Prueba Chefito ahora',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Experimenta cómo funciona nuestro asistente de cocina inteligente',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDemoCard(
                title: 'Simular Escaneo',
                description: 'Prueba cómo funciona el escaneo de tickets',
                icon: Icons.camera_alt,
                color: Colors.blue,
                onTap: _simulateReceiptScan,
              ),
              const SizedBox(width: 30),
              _buildDemoCard(
                title: 'Ver Mi Inventario',
                description: 'Revisa los ingredientes disponibles',
                icon: Icons.inventory,
                color: Colors.green,
                onTap: () => setState(() => _showInventory = true),
              ),
              const SizedBox(width: 30),
              _buildDemoCard(
                title: 'Generar Receta IA',
                description: 'Deja que ChatGPT sugiera una receta',
                icon: Icons.auto_fix_high,
                color: Colors.purple,
                onTap: _generateRecipe,
                isLoading: _isLoadingRecipe,
              ),
            ],
          ),
          if (_showInventory) ...[
            const SizedBox(height: 40),
            _buildInventoryDisplay(),
          ],
        ],
      ),
    );
  }

  Widget _buildDemoCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              spreadRadius: 0,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color],
                ),
                borderRadius: BorderRadius.circular(35),
              ),
              child: isLoading
                  ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    )
                  : Icon(
                      icon,
                      size: 35,
                      color: Colors.white,
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryDisplay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mi Inventario (${_inventoryService.ingredients.length} ingredientes)',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showInventory = false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _inventoryService.ingredients
                .map((ingredient) => Chip(
                      label: Text(ingredient),
                      backgroundColor: Colors.green[100],
                      labelStyle: TextStyle(color: Colors.green[800]),
                      deleteIcon: const Icon(Icons.close, size: 18),
                      onDeleted: () {
                        setState(() {
                          _inventoryService.removeIngredient(ingredient);
                        });
                      },
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      child: Column(
        children: [
          Text(
            'Lo que dicen nuestros usuarios',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTestimonialCard(
                name: 'María González',
                role: 'Madre de familia',
                testimonial: 'Chefito me ha ahorrado horas de planificación. Ahora cocino más variado y desperdicio menos comida.',
                avatar: '👩‍🍳',
                rating: 5,
              ),
              _buildTestimonialCard(
                name: 'Carlos Ruiz',
                role: 'Chef profesional',
                testimonial: 'La IA de Chefito sugiere combinaciones que nunca se me habrían ocurrido. Increíble para la creatividad culinaria.',
                avatar: '👨‍🍳',
                rating: 5,
              ),
              _buildTestimonialCard(
                name: 'Ana Martín',
                role: 'Estudiante universitaria',
                testimonial: 'Perfecto para mi presupuesto de estudiante. Aprovecho al máximo cada compra del súper.',
                avatar: '👩‍🎓',
                rating: 5,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonialCard({
    required String name,
    required String role,
    required String testimonial,
    required String avatar,
    required int rating,
  }) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            avatar,
            style: const TextStyle(fontSize: 50),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              rating,
              (index) => Icon(
                Icons.star,
                color: Colors.yellow[600],
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '"$testimonial"',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTASection() {
    return Container(
      key: const Key('cta'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green[600]!,
            Colors.green[400]!,
          ],
        ),
      ),
      child: Column(
        children: [
          const Text(
            '¿Listo para cocinar más inteligente?',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Únete a miles de usuarios que ya cocinan con Chefito',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  // Aquí iría la lógica de registro
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Gracias por tu interés! Te contactaremos pronto.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.rocket_launch),
                label: const Text('Comenzar Gratis'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {
                  // Aquí iría la lógica de newsletter
                  _showNewsletterDialog();
                },
                icon: const Icon(Icons.email),
                label: const Text('Newsletter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      color: Colors.grey[800],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[400]!, Colors.green[600]!],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppConfig.appName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tu asistente de cocina inteligente',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildFooterLink('Funciones'),
                  const SizedBox(width: 24),
                  _buildFooterLink('Precios'),
                  const SizedBox(width: 24),
                  _buildFooterLink('Soporte'),
                  const SizedBox(width: 24),
                  _buildFooterLink('Contacto'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.grey[600]),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '© 2025 ${AppConfig.appName}. Todos los derechos reservados.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
              Row(
                children: [
                  Text(
                    'Hecho con ❤️ y Flutter',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'v${AppConfig.appVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text) {
    return TextButton(
      onPressed: () {},
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[300],
          fontSize: 14,
        ),
      ),
    );
  }

  void _scrollToSection(String section) {
    // En una implementación real, usaríamos ScrollController
    // Por ahora, solo mostramos un mensaje
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navegando a sección: $section'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _showNewsletterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suscríbete al Newsletter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Recibe las últimas novedades y recetas exclusivas'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Tu email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('¡Gracias por suscribirte!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Suscribirse'),
          ),
        ],
      ),
    );
  }

  // Modal para mostrar receta generada
  void _showRecipeModal() {
    if (_currentRecipe == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          height: 700,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _currentRecipe!.nombre,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _currentRecipe!.descripcion,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Chip(
                    label: Text(_currentRecipe!.tiempoPreparacion),
                    backgroundColor: Colors.blue[100],
                  ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(_currentRecipe!.dificultad),
                    backgroundColor: Colors.green[100],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Ingredientes que tienes:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentRecipe!.ingredientesUsados
                    .map((ingredient) => Chip(
                          label: Text(ingredient),
                          backgroundColor: Colors.green[100],
                          avatar: const Icon(Icons.check, size: 16, color: Colors.green),
                        ))
                    .toList(),
              ),
              if (_currentRecipe!.ingredientesFaltantes.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Ingredientes que necesitas:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _currentRecipe!.ingredientesFaltantes
                      .map((ingredient) => Chip(
                            label: Text(ingredient),
                            backgroundColor: Colors.orange[100],
                            avatar: const Icon(Icons.shopping_cart, size: 16, color: Colors.orange),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Pasos de preparación:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _currentRecipe!.pasos.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.green[600],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _currentRecipe!.pasos[index],
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_currentRecipe!.videoSugerido != null) {
                          html.window.open(_currentRecipe!.videoSugerido!, '_blank');
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Ver Video'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('¡Receta guardada en favoritos!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.favorite),
                      label: const Text('Guardar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Mostrar modal de receta cuando esté disponible
    if (_showRecipeModal && _currentRecipe != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRecipeModal();
        setState(() {
          _showRecipeModal = false;
        });
      });
    }
  }
}