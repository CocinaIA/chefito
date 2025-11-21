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
      appBar: AppBar(
        title: const Text('Recetas sugeridas'),
        actions: [
          IconButton(
            onPressed: () async {
              await AIRecipesStorage.clearRecipes();
              if (mounted) {
                setState(() => _aiRecipes = []);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Recetas IA borradas')),
                );
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
          IconButton(
            onPressed: (_aiLoading || _pantry.isEmpty) ? null : _generateAI,
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Generar con IA',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (!hasCatalogRecipes && !hasAIRecipes)
                  _Empty(matches: _matches, pantry: displayPantry),
                if (hasCatalogRecipes) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Catálogo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.foreground,
                      ),
                    ),
                  ),
                  ..._matches.map(_matchTile),
                ],
                if (_aiLoading)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
                  ),
                if (hasAIRecipes) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'IA (generadas)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  ..._aiRecipes.asMap().entries.map((entry) {
                    final index = entry.key;
                    final recipe = entry.value;
                    return _aiTileWithAnimation(recipe, index);
                  }),
                ],
                const SizedBox(height: 16),
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
        collapsedBackgroundColor: AppTheme.primaryLight.withOpacity(0.05),
        backgroundColor: AppTheme.primaryLight.withOpacity(0.05),
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

  Widget _aiTile(Map<String, dynamic> r) {
    // This method is now replaced by _aiTileWithAnimation
    // Kept for backwards compatibility but not used
    return const SizedBox.shrink();
  }

  Widget _aiTileWithAnimation(Map<String, dynamic> r, int index) {
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
                    color: getDifficultyColor(difficulty).withOpacity(0.2),
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
                      unit: parts['unit'] ?? '',
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
                      unit: parts['unit'] ?? '',
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
                colors: [gradientPair[0].withOpacity(0.1), gradientPair[1].withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: gradientPair[0].withOpacity(0.3),
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
  Future<void> _markRecipeAsUsed(String recipeName, List<String> usedIngredients) async {
    if (usedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay ingredientes para consumir')),
      );
      return;
    }

    try {
      for (final ingredientWithQuantity in usedIngredients) {
        debugPrint('🔍 Procesando: $ingredientWithQuantity');
        
        // Parse the ingredient string to extract quantity, unit, and name
        // Format: "300g arroz", "2 huevos", "100ml aceite", "1 cebolla"
        final match = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-záéíóúñ\s]*?)\s+(.+)$')
            .firstMatch(ingredientWithQuantity.trim());
        
        if (match == null) {
          debugPrint('⚠️ No se pudo parsear: $ingredientWithQuantity');
          continue;
        }

        final recipeQuantity = double.tryParse(match.group(1) ?? '0') ?? 0;
        final recipeUnit = (match.group(2) ?? '').trim();
        final ingredientName = (match.group(3) ?? '').toLowerCase().trim();
        
        debugPrint('📊 Parsado: $recipeQuantity $recipeUnit de $ingredientName');

        // Find the ingredient in our pantry
        Ingredient? matchingIngredient;
        try {
          matchingIngredient = _ingredients.firstWhere(
            (ing) => ing.baseIngredient.toLowerCase() == ingredientName ||
                     ing.name.toLowerCase().contains(ingredientName) ||
                     ingredientName.contains(ing.name.toLowerCase()),
          );
        } catch (e) {
          debugPrint('⚠️ No se encontró ingrediente: $ingredientName');
          debugPrint('📋 Disponibles: ${_ingredients.map((i) => '${i.name} (${i.quantity}${i.unit})').join(', ')}');
          continue;
        }

        if (matchingIngredient == null) {
          debugPrint('❌ No encontrado: $ingredientName');
          continue;
        }

        // If recipe unit matches pantry unit, consume exact amount
        // Otherwise, try a reasonable conversion or consume proportionally
        double consumeAmount;
        
        if (recipeUnit.toLowerCase() == matchingIngredient.unit.toLowerCase()) {
          // Same unit: consume exactly what the recipe says
          consumeAmount = recipeQuantity;
        } else {
          // Different units: consume proportionally (1/3 of what's available)
          consumeAmount = (matchingIngredient.quantity / 3).clamp(1.0, matchingIngredient.quantity);
          debugPrint('⚠️ Unidades diferentes (receta: $recipeUnit, pantry: ${matchingIngredient.unit}). Consumiendo proporcionalmente.');
        }
        
        debugPrint('✅ Consumiendo $consumeAmount ${matchingIngredient.unit} de ${matchingIngredient.name}');
        await _repo.consumeIngredient(matchingIngredient.id, consumeAmount);
      }

      // Reload pantry
      await _load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Receta "$recipeName" cocinada. Stock actualizado.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error general: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar stock: $e')),
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
          color: textColor.withOpacity(0.3),
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
                color: textColor.withOpacity(0.15),
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
