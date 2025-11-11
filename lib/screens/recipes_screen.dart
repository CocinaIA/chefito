import 'package:flutter/material.dart';

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
    // Strip quantity suffixes from items for recipe matching
    final stripped = _normalizedPantry(items);
    final normalized = IngredientNormalizer.normalize(stripped);
    final matches = RecipeRecommender.recommend(pantry: normalized, minCoverage: 0.4);
    
    // Load cached AI recipes if available
    final cached = await AIRecipesStorage.loadRecipes();
    
    setState(() {
      _pantry = items; // Keep original with quantities for display
      _matches = matches;
      _aiRecipes = cached; // Restore cached recipes
      _loading = false;
    });
  }

  Future<void> _generateAI() async {
    final normalizedForAI = _normalizedPantry(_pantry);
    if (normalizedForAI.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La alacena está vacía. Escanea un ticket o agrega ingredientes antes de generar.')),
        );
      }
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final out = await _ai.generate(ingredients: normalizedForAI, max: 5);
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
<<<<<<< HEAD
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
=======
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
>>>>>>> bd5e1a4db3b7ca693b2ea8871ff0eedf85548521
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
                  ..._aiRecipes.map(_aiTile),
                  const SizedBox(height: 16),
                ],
                
                // Recetas del catálogo
                if (_matches.isEmpty && _aiRecipes.isEmpty)
                  _Empty(matches: _matches, pantry: _panryPreview()),
                  
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
<<<<<<< HEAD
                
                const SizedBox(height: 24),
=======
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
>>>>>>> bd5e1a4db3b7ca693b2ea8871ff0eedf85548521
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
    final used = ((r['used'] as List?) ?? []).cast<String>();
    final missing = ((r['missing'] as List?) ?? []).cast<String>();
    final steps = ((r['steps'] as List?) ?? []).cast<String>();
    
    // Gradient colors that cycle
    final gradients = [
      [const Color(0xFFFEAA00), const Color(0xFFFF8C3A)],
      [const Color(0xFF10B981), const Color(0xFF059669)],
      [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
      [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
      [const Color(0xFFEC4899), const Color(0xFFFDBE24)],
    ];
    final gradientPair = gradients[index % gradients.length];
    
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
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.foreground,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '✅ ${used.length} usados',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: missing.isEmpty ? Colors.blue.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  missing.isEmpty ? '🎉 Completa' : '❌ Faltan ${missing.length}',
                  style: TextStyle(
                    color: missing.isEmpty ? Colors.blue.shade700 : Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        collapsedBackgroundColor: Color.lerp(gradientPair[0], Colors.white, 0.85) ?? Colors.white,
        backgroundColor: Color.lerp(gradientPair[0], Colors.white, 0.90) ?? Colors.white,
        iconColor: gradientPair[0],
        collapsedIconColor: gradientPair[0],
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (used.isNotEmpty)
            _ChipsRow(label: 'Usas', items: used, color: Colors.green.shade100),
          if (missing.isNotEmpty)
            _ChipsRow(label: 'Te falta', items: missing, color: Colors.orange.shade100),
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
