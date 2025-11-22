import 'package:flutter/material.dart';

import '../models/ingredient.dart';
import '../services/pantry_repository.dart';
import '../services/ingredient_normalizer.dart';
import '../services/recipe_recommender.dart';
import '../services/recipe_ai_service.dart';
import '../services/ai_recipes_storage.dart';
import '../theme.dart';

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final _repo = PantryRepository();
  final _ai = RecipeAIService();
  List<String> _pantry = [];
  List<Ingredient> _ingredients = [];
  List<RecipeMatch> _matches = [];
  List<Map<String, dynamic>> _aiRecipes = [];
  bool _loading = true;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Extract base ingredient name from "name (quantity)" format
  String _baseIngredient(String ingredient) {
    final idx = ingredient.lastIndexOf('(');
    if (idx > 0) {
      return ingredient.substring(0, idx).trim();
    }
    return ingredient;
  }

  /// Normalize pantry items by removing quantity suffixes
  List<String> _normalizedPantry(List<String> pantry) {
    return pantry.map(_baseIngredient).toList();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.getAllItems();
    final ingredients = await _repo.getAllIngredients();
    
    // Strip quantity suffixes from items for recipe matching
    final stripped = _normalizedPantry(items);
    final normalized = IngredientNormalizer.normalize(stripped);
    final matches = RecipeRecommender.recommend(pantry: normalized, minCoverage: 0.4);
    
    // Load cached AI recipes if available
    final cached = await AIRecipesStorage.loadRecipes();
    
    setState(() {
      _pantry = items; // Keep original with quantities for display
      _ingredients = ingredients; // Store full Ingredient objects
      _matches = matches;
      _aiRecipes = cached; // Restore cached recipes
      _loading = false;
    });
  }

  Future<void> _generateAI() async {
    if (_ingredients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La alacena está vacía. Escanea un ticket o agrega ingredientes antes de generar.')),
        );
      }
      return;
    }
    setState(() => _aiLoading = true);
    try {
      // Send ingredients WITH quantities to AI
      // Using 5 recipes instead of 8 to reduce server errors (less data = less truncation)
      final out = await _ai.generate(
        ingredients: _pantry,
        ingredientsWithQuantity: _ingredients,
        max: 5,
      );
      setState(() => _aiRecipes = out);
      // Save generated recipes to storage
      await AIRecipesStorage.saveRecipes(out);
      if (mounted && out.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La IA no generó recetas.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error IA: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayPantry = _pantry.take(8).join(', ');
    final hasAIRecipes = _aiRecipes.isNotEmpty;
    final hasCatalogRecipes = _matches.isNotEmpty;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Recetas Sugeridas'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            onPressed: () async {
              // Show confirmation dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
                      const SizedBox(width: 12),
                      const Text('¿Eliminar recetas?'),
                    ],
                  ),
                  content: const Text(
                    'Se borrarán todas las recetas generadas por IA. Esta acción no se puede deshacer.',
                    style: TextStyle(fontSize: 15),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Sí, eliminar'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await AIRecipesStorage.clearRecipes();
                if (mounted) {
                  setState(() => _aiRecipes = []);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Recetas IA eliminadas'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Borrar recetas IA',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando recetas...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // Botón prominente de IA
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primary,
                          AppTheme.primaryDark,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: (_aiLoading || _pantry.isEmpty) ? null : _generateAI,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _aiLoading
                                          ? 'Generando recetas...'
                                          : 'Generar con IA',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _pantry.isEmpty
                                          ? 'Agrega ingredientes primero'
                                          : 'Crea recetas personalizadas',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_aiLoading)
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              else if (_pantry.isNotEmpty)
                                const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 24,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Recetas generadas por IA
                if (_aiRecipes.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Generadas con IA',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._aiRecipes.asMap().entries.map((entry) => _aiTile(entry.value, entry.key)),
                  const SizedBox(height: 16),
                ],
                
                // Recetas del catálogo
                if (_matches.isEmpty && _aiRecipes.isEmpty)
                  _Empty(matches: _matches, pantry: _pantry.join(', ')),
                  
                if (_matches.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.restaurant_menu,
                            color: AppTheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Del catálogo',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppTheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._matches.map(_matchTile),
                ],
                
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  String _subtitle(RecipeMatch m) {
    final used = m.used.length;
    final total = m.recipe.ingredients.length;
    final miss = m.missing.length;
    return '$used de $total ingredientes • ${miss == 0 ? 'completa' : 'faltan $miss'}';
  }

  Widget _matchTile(RecipeMatch m) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryLight,
          child: Text(
            '${(m.score * 100).round()}%',
            style: const TextStyle(
              color: AppTheme.foreground,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          m.recipe.name,
          style: const TextStyle(
            color: AppTheme.foreground,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          _subtitle(m),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        collapsedBackgroundColor: AppTheme.primaryLight.withValues(alpha: 0.05),
        backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.05),
        iconColor: AppTheme.primary,
        collapsedIconColor: AppTheme.primary,
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (m.used.isNotEmpty)
            _ChipsRow(label: 'Usas', items: m.used, color: Colors.green.shade100),
          if (m.missing.isNotEmpty)
            _ChipsRow(label: 'Te falta', items: m.missing, color: Colors.orange.shade100),
          if (m.recipe.steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Pasos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...m.recipe.steps.map((s) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle, size: 18, color: AppTheme.primary),
                  title: Text(
                    s,
                    style: const TextStyle(color: AppTheme.foreground, fontSize: 14),
                  ),
                )),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _aiTile(Map<String, dynamic> r, int index) {
    final title = (r['title'] ?? 'Receta').toString();
    final description = (r['description'] ?? '').toString().trim();
    final servings = (r['servings'] ?? '').toString().trim();
    final time = (r['time'] ?? '').toString().trim();
    final difficulty = (r['difficulty'] ?? 'medium').toString().trim();
    final used = ((r['used'] as List?) ?? []).cast<String>();
    final missing = ((r['missing'] as List?) ?? []).cast<String>();
    final steps = ((r['steps'] as List?) ?? []).cast<String>();
    final tips = ((r['tips'] as List?) ?? []).cast<String>();
    final variations = ((r['variations'] as List?) ?? []).cast<String>();
    
    // Gradient colors that cycle
    final gradients = [
      [const Color(0xFFFEAA00), const Color(0xFFFF8C3A)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
      [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
      [const Color(0xFFEC4899), const Color(0xFFFDBE24)],
    ];
    final gradientPair = gradients[index % gradients.length];
    
    // Difficulty badge color
    Color getDifficultyColor(String diff) {
      switch (diff.toLowerCase()) {
        case 'easy':
          return Colors.green;
        case 'medium':
          return Colors.orange;
        case 'hard':
          return Colors.red;
        default:
          return Colors.blue;
      }
    }

    String getDifficultyEmoji(String diff) {
      switch (diff.toLowerCase()) {
        case 'easy':
          return '😊';
        case 'medium':
          return '👨‍🍳';
        case 'hard':
          return '🔥';
        default:
          return '🍳';
      }
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientPair,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (servings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '🍽️ $servings',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '⏱️ $time',
                        style: TextStyle(
                          color: Colors.purple.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getDifficultyColor(difficulty).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${getDifficultyEmoji(difficulty)} ${difficulty[0].toUpperCase()}${difficulty.substring(1)}',
                    style: TextStyle(
                      color: getDifficultyColor(difficulty),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '✅ ${used.length}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        collapsedBackgroundColor: Color.lerp(gradientPair[0], Colors.white, 0.85) ?? Colors.white,
        backgroundColor: Color.lerp(gradientPair[0], Colors.white, 0.90) ?? Colors.white,
        iconColor: gradientPair[0],
        collapsedIconColor: gradientPair[0],
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (used.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Usas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.foreground,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: used.map((ingredient) {
                    // Parse ingredient name and quantity
                    final parts = _parseIngredient(ingredient);
                    return _IngredientChip(
                      name: parts['name'] ?? ingredient,
                      quantity: parts['quantity'] ?? '',
                      unit: _expandUnit(parts['unit'] ?? ''),
                      backgroundColor: Colors.green.shade100,
                      textColor: Colors.green.shade700,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          if (missing.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Te falta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.foreground,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: missing.map((ingredient) {
                    // Parse ingredient name and quantity
                    final parts = _parseIngredient(ingredient);
                    return _IngredientChip(
                      name: parts['name'] ?? ingredient,
                      quantity: parts['quantity'] ?? '',
                      unit: _expandUnit(parts['unit'] ?? ''),
                      backgroundColor: Colors.orange.shade100,
                      textColor: Colors.orange.shade700,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '👨‍🍳 Pasos para preparar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              final stepIndex = entry.key + 1;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradientPair,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$stepIndex',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(
                          color: AppTheme.foreground,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '💡 Consejos profesionales',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...tips.map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✨ ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(
                          color: AppTheme.foreground,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (variations.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '🔄 Variaciones',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...variations.map((variation) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('👉 ', style: TextStyle(fontSize: 16)),
                    Expanded(
                      child: Text(
                        variation,
                        style: const TextStyle(
                          color: AppTheme.foreground,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientPair[0].withValues(alpha: 0.1), gradientPair[1].withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: gradientPair[0].withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '💡',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Receta generada con IA! Puedes guardarla en tus favoritos.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Button to mark recipe as used and update stock
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: gradientPair[0],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _markRecipeAsUsed(title, used),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('✓ Marcar como cocinada'),
            ),
          ),
        ],
      ),
    );
  }

  /// Expand unit abbreviations to full names
  String _expandUnit(String unit) {
    if (unit.isEmpty) return '';
    
    final unitMap = {
      'g': 'gramos',
      'kg': 'kilogramos',
      'ml': 'mililitros',
      'l': 'litros',
      'cucharada': 'cucharadas',
      'taza': 'tazas',
      'unidad': 'unidad',
    };
    
    final lowerUnit = unit.toLowerCase().trim();
    return unitMap[lowerUnit] ?? unit;
  }

  /// Parse ingredient string to extract name, quantity, and unit
  /// Handles formats like: "arroz (500g)", "huevos (3 unidad)", "aceite (2 cucharadas)"
  Map<String, String> _parseIngredient(String ingredient) {
    // Try to match pattern: "name (quantity unit)" or "name (quantity)"
    final match = RegExp(r'^(.+?)\s*\((\d+(?:\.\d+)?)\s*([a-záéíóúñ\s]*)\)').firstMatch(ingredient);
    
    if (match != null) {
      return {
        'name': match.group(1)?.trim() ?? ingredient,
        'quantity': match.group(2)?.trim() ?? '',
        'unit': match.group(3)?.trim() ?? '',
      };
    }
    
    // Return original ingredient if no match
    return {'name': ingredient, 'quantity': '', 'unit': ''};
  }

  // Mark recipe as used and update stock in Firebase
  /// Convert between different units of measurement
  /// Returns the converted quantity, or null if conversion is not possible
  double? _convertUnits(double quantity, String fromUnit, String toUnit) {
    if (fromUnit.toLowerCase() == toUnit.toLowerCase()) {
      return quantity;
    }

    final from = fromUnit.toLowerCase().trim();
    final to = toUnit.toLowerCase().trim();

    // Weight conversions (g <-> kg)
    if ((from == 'g' && to == 'kg') || (from == 'gramos' && to == 'kg')) {
      return quantity / 1000;
    }
    if ((from == 'kg' && to == 'g') || (from == 'kg' && to == 'gramos')) {
      return quantity * 1000;
    }

    // Volume conversions (ml <-> l)
    if ((from == 'ml' && to == 'l') || (from == 'mililitros' && to == 'l')) {
      return quantity / 1000;
    }
    if ((from == 'l' && to == 'ml') || (from == 'l' && to == 'mililitros')) {
      return quantity * 1000;
    }

    // Tablespoon to ml (1 cucharada = 15ml aprox)
    if ((from == 'cucharada' || from == 'cucharadas') && (to == 'ml' || to == 'mililitros')) {
      return quantity * 15;
    }
    if ((to == 'cucharada' || to == 'cucharadas') && (from == 'ml' || from == 'mililitros')) {
      return quantity / 15;
    }

    // Cup to ml (1 taza = 240ml aprox)
    if ((from == 'taza' || from == 'tazas') && (to == 'ml' || to == 'mililitros')) {
      return quantity * 240;
    }
    if ((to == 'taza' || to == 'tazas') && (from == 'ml' || from == 'mililitros')) {
      return quantity / 240;
    }

    // For "unidad" we cannot convert
    return null;
  }

  /// Parse ingredient string with multiple format support
  /// Formats: "arroz (500g)", "500g arroz", "500 g de arroz", "2 huevos"
  Map<String, dynamic> _parseIngredientForConsumption(String ingredientStr) {
    final str = ingredientStr.trim();
    
    // Format 1: "arroz (500g)" or "arroz (500 g)"
    var match = RegExp(r'^(.+?)\s*\((\d+(?:\.\d+)?)\s*([a-záéíóúñ]*)\s*\)$', caseSensitive: false)
        .firstMatch(str);
    if (match != null) {
      return {
        'name': match.group(1)!.trim().toLowerCase(),
        'quantity': double.tryParse(match.group(2)!) ?? 0.0,
        'unit': match.group(3)!.trim().toLowerCase(),
      };
    }
    
    // Format 2: "500g arroz" or "500 g arroz"
    match = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-záéíóúñ]*)\s+(.+)$', caseSensitive: false)
        .firstMatch(str);
    if (match != null) {
      return {
        'name': match.group(3)!.trim().toLowerCase(),
        'quantity': double.tryParse(match.group(1)!) ?? 0.0,
        'unit': match.group(2)!.trim().toLowerCase(),
      };
    }
    
    // Format 3: "500 g de arroz"
    match = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-záéíóúñ]*)\s+de\s+(.+)$', caseSensitive: false)
        .firstMatch(str);
    if (match != null) {
      return {
        'name': match.group(3)!.trim().toLowerCase(),
        'quantity': double.tryParse(match.group(1)!) ?? 0.0,
        'unit': match.group(2)!.trim().toLowerCase(),
      };
    }
    
    // Format 4: Just a number and name "2 huevos"
    match = RegExp(r'^(\d+(?:\.\d+)?)\s+(.+)$', caseSensitive: false)
        .firstMatch(str);
    if (match != null) {
      return {
        'name': match.group(2)!.trim().toLowerCase(),
        'quantity': double.tryParse(match.group(1)!) ?? 0.0,
        'unit': 'unidad',
      };
    }
    
    // Fallback: just the name, no quantity
    return {
      'name': str.toLowerCase(),
      'quantity': 0.0,
      'unit': 'unidad',
    };
  }

  /// Find matching ingredient in pantry using fuzzy matching
  Ingredient? _findIngredientInPantry(String searchName) {
    searchName = searchName.toLowerCase().trim();
    
    // Try exact match on baseIngredient first
    for (final ing in _ingredients) {
      if (ing.baseIngredient.toLowerCase() == searchName) {
        return ing;
      }
    }
    
    // Try exact match on name
    for (final ing in _ingredients) {
      if (ing.name.toLowerCase() == searchName) {
        return ing;
      }
    }
    
    // Try contains match
    for (final ing in _ingredients) {
      if (ing.name.toLowerCase().contains(searchName) || 
          searchName.contains(ing.name.toLowerCase())) {
        return ing;
      }
    }
    
    return null;
  }

  /// Calculate smart portion based on pantry quantity
  double _calculateSmartPortion(Ingredient ingredient, int numPeople) {
    // Base portions per person for common items
    final portions = {
      'g': 100.0,      // 100g per person for solid foods
      'kg': 0.1,       // 100g per person
      'ml': 150.0,     // 150ml per person for liquids
      'l': 0.15,       // 150ml per person
      'unidad': 1.0,   // 1 unit per person
    };
    
    final baseAmount = portions[ingredient.unit.toLowerCase()] ?? 100.0;
    final totalNeeded = baseAmount * numPeople;
    
    // Use minimum between what we need and what we have
    // But use at least 10% of available stock
    final minUse = ingredient.quantity * 0.1;
    final calculated = totalNeeded.clamp(minUse, ingredient.quantity);
    
    debugPrint('📊 Calculado inteligente: $calculated ${ingredient.unit} (disponible: ${ingredient.quantity})');
    return calculated;
  }

  Future<void> _markRecipeAsUsed(String recipeName, List<String> usedIngredients) async {
    if (usedIngredients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay ingredientes para consumir')),
        );
      }
      return;
    }

    // Calculate what will be consumed
    final List<Map<String, dynamic>> consumptionPlan = [];
    const int numPeople = 2; // Default serving size
    
    for (final ingredientStr in usedIngredients) {
      debugPrint('🔍 Procesando: $ingredientStr');
      
      final parsed = _parseIngredientForConsumption(ingredientStr);
      final ingredientName = parsed['name'] as String;
      var recipeQuantity = parsed['quantity'] as double;
      final recipeUnit = parsed['unit'] as String;
      
      debugPrint('📊 Parsado: $recipeQuantity $recipeUnit de $ingredientName');

      // Find the ingredient in our pantry
      final matchingIngredient = _findIngredientInPantry(ingredientName);
      
      if (matchingIngredient == null) {
        debugPrint('⚠️ No se encontró ingrediente: $ingredientName');
        debugPrint('📋 Disponibles: ${_ingredients.map((i) => i.name).join(', ')}');
        continue;
      }
      
      // If no quantity provided by AI, calculate smart portion
      if (recipeQuantity == 0) {
        recipeQuantity = _calculateSmartPortion(matchingIngredient, numPeople);
        debugPrint('💡 IA no dio cantidad, usando cálculo inteligente: $recipeQuantity ${matchingIngredient.unit}');
      }

      // Calculate consume amount with unit conversion
      double consumeAmount;
      String displayUnit = matchingIngredient.unit;
      
      if (recipeUnit == matchingIngredient.unit.toLowerCase() || recipeUnit.isEmpty) {
        // Same unit or no unit specified: use recipe quantity
        consumeAmount = recipeQuantity;
        debugPrint('✅ Unidades iguales: $consumeAmount $displayUnit');
      } else {
        // Try to convert recipe quantity to pantry unit
        final converted = _convertUnits(recipeQuantity, recipeUnit, matchingIngredient.unit);
        if (converted != null) {
          consumeAmount = converted;
          debugPrint('✅ Conversión: $recipeQuantity $recipeUnit = $consumeAmount $displayUnit');
        } else {
          // Can't convert, use recipe quantity as-is
          consumeAmount = recipeQuantity;
          displayUnit = recipeUnit;
          debugPrint('⚠️ No se pudo convertir, usando $consumeAmount $displayUnit');
        }
      }
      
      // Ensure we don't consume more than available
      if (consumeAmount > matchingIngredient.quantity) {
        consumeAmount = matchingIngredient.quantity;
        debugPrint('⚠️ Ajustado a disponible: $consumeAmount');
      }
      
      consumptionPlan.add({
        'ingredient': matchingIngredient,
        'consume': consumeAmount,
        'displayUnit': _expandUnit(displayUnit),
        'remaining': matchingIngredient.quantity - consumeAmount,
      });
    }
    
    if (consumptionPlan.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron procesar los ingredientes')),
        );
      }
      return;
    }

    // Show confirmation dialog
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar receta cocinada'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se consumirán los siguientes ingredientes:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.foreground,
                ),
              ),
              const SizedBox(height: 16),
              ...consumptionPlan.map((plan) {
                final ing = plan['ingredient'] as Ingredient;
                final consume = plan['consume'] as double;
                final unit = plan['displayUnit'] as String;
                final remaining = plan['remaining'] as double;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ing.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Usar: $consume $unit',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Queda: ${remaining.toStringAsFixed(1)} ${_expandUnit(ing.unit)}',
                                    style: TextStyle(
                                      color: remaining > 0 ? Colors.green.shade700 : Colors.red.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Execute consumption
    try {
      for (final plan in consumptionPlan) {
        final ing = plan['ingredient'] as Ingredient;
        final consume = plan['consume'] as double;
        
        debugPrint('✅ Consumiendo $consume de ${ing.name}');
        await _repo.consumeIngredient(ing.id, consume);
      }

      // Reload pantry
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Receta "$recipeName" cocinada. Stock actualizado.'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar stock: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Widget para mostrar un ingrediente con cantidad y unidad de forma separada y llamativa
class _IngredientChip extends StatelessWidget {
  final String name;
  final String quantity;
  final String unit;
  final Color backgroundColor;
  final Color textColor;

  const _IngredientChip({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasQuantity = quantity.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nombre del ingrediente (bold)
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasQuantity) ...[
            const SizedBox(width: 6),
            // Badge con cantidad y unidad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$quantity ${unit.isNotEmpty ? unit : ''}'.trim(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChipsRow extends StatelessWidget {
  final String label;
  final List<String> items;
  final Color color;
  const _ChipsRow({required this.label, required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.foreground,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((e) => Chip(
                    label: Text(
                      e,
                      style: const TextStyle(
                        color: AppTheme.foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: color,
                    side: BorderSide.none,
                  ))
              .toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final List<RecipeMatch> matches;
  final String pantry;
  const _Empty({required this.matches, required this.pantry});

  @override
  Widget build(BuildContext context) {
    final isPantryEmpty = pantry.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fastfood, size: 64, color: AppTheme.primaryLight),
            const SizedBox(height: 16),
            Text(
              'Aún no hay recetas coincidentes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.foreground,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isPantryEmpty
                  ? 'Tu alacena está vacía. Escanea un ticket o agrega ingredientes.'
                  : 'Con tu alacena: $pantry',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
