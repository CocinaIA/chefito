import 'package:flutter/material.dart';

import '../services/pantry_repository.dart';
import '../services/ingredient_normalizer.dart';
import '../services/recipe_recommender.dart';
import '../services/recipe_ai_service.dart';
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

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.getAllItems();
    // Ensure normalized tokens
    final normalized = IngredientNormalizer.normalize(items);
    final matches = RecipeRecommender.recommend(pantry: normalized, minCoverage: 0.4);
    setState(() {
      _pantry = normalized..sort();
      _matches = matches;
      _loading = false;
    });
  }

  Future<void> _generateAI() async {
    if (_pantry.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La alacena está vacía. Escanea un ticket o agrega ingredientes antes de generar.')),
        );
      }
      return;
    }
    setState(() => _aiLoading = true);
    try {
      final out = await _ai.generate(ingredients: _pantry, max: 5);
      setState(() => _aiRecipes = out);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recetas sugeridas'),
        actions: [
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
                if (_matches.isEmpty)
                  _Empty(matches: _matches, pantry: _panryPreview()),
                if (_matches.isNotEmpty) ...[
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
                if (_aiRecipes.isNotEmpty) ...[
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
                  ..._aiRecipes.map(_aiTile),
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

  String _panryPreview() => _pantry.take(8).join(', ');

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
    final title = (r['title'] ?? 'Receta').toString();
    final used = ((r['used'] as List?) ?? []).cast<String>();
    final missing = ((r['missing'] as List?) ?? []).cast<String>();
    final steps = ((r['steps'] as List?) ?? []).cast<String>();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 24),
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.foreground,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${used.length} usados • ${missing.isEmpty ? 'completa' : 'faltan ${missing.length}'}',
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
          if (used.isNotEmpty)
            _ChipsRow(label: 'Usas', items: used, color: Colors.blue.shade100),
          if (missing.isNotEmpty)
            _ChipsRow(label: 'Te falta', items: missing, color: Colors.orange.shade100),
          if (steps.isNotEmpty) ...[
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
            ...steps.map((s) => ListTile(
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
              pantry.isEmpty
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
