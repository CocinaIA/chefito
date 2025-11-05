class Recipe {
  final String id;
  final String name;
  final List<String> ingredients; // canonical, normalized tokens
  final List<String> steps;

  const Recipe({
    required this.id,
    required this.name,
    required this.ingredients,
    this.steps = const [],
  });
}

class RecipeMatch {
  final Recipe recipe;
  final double score; // 0..1 coverage score
  final List<String> missing;
  final List<String> used;

  const RecipeMatch({
    required this.recipe,
    required this.score,
    required this.missing,
    required this.used,
  });
}

/// Simple in-memory recipe base for MVP. You can replace this with Firestore later.
class RecipeCatalog {
  static final List<Recipe> demo = [
    const Recipe(
      id: 'arepas-queso',
      name: 'Arepas con queso',
      ingredients: ['harina maiz', 'agua', 'sal', 'queso'],
      steps: [
        'Mezcla harina de maiz con agua y sal hasta formar una masa.',
        'Forma arepas, cocina a la plancha y agrega queso al final.',
      ],
    ),
    const Recipe(
      id: 'pasta-tomate',
      name: 'Pasta con salsa de tomate',
      ingredients: ['pasta', 'tomate', 'aceite', 'ajo', 'sal'],
      steps: [
        'Hierve la pasta con sal.',
        'Sofríe ajo en aceite, agrega tomate y cocina.',
        'Mezcla con la pasta y ajusta sal.',
      ],
    ),
    const Recipe(
      id: 'arroz-pollo-simple',
      name: 'Arroz con pollo (simple)',
      ingredients: ['arroz', 'pollo', 'cebolla', 'aceite', 'sal'],
    ),
    const Recipe(
      id: 'ensalada-verde',
      name: 'Ensalada verde',
      ingredients: ['lechuga', 'pepino', 'tomate', 'aceite', 'sal'],
    ),
    const Recipe(
      id: 'huevos-revueltos',
      name: 'Huevos revueltos',
      ingredients: ['huevo', 'sal', 'aceite'],
    ),
  ];
}

class RecipeRecommender {
  /// Returns top recipes sorted by score based on pantry items (already normalized!).
  /// - coverage score = used / recipe.size
  /// - ties broken by fewer missing ingredients
  /// - minCoverage: filter recipes below this coverage
  static List<RecipeMatch> recommend({
    required List<String> pantry,
    List<Recipe>? catalog,
    double minCoverage = 0.5,
    int maxResults = 10,
  }) {
    final set = pantry.map((e) => e.toLowerCase()).toSet();
    final recipes = catalog ?? RecipeCatalog.demo;
    final matches = <RecipeMatch>[];

    for (final r in recipes) {
      final req = r.ingredients.map((e) => e.toLowerCase()).toList();
      final used = req.where(set.contains).toList();
      final missing = req.where((e) => !set.contains(e)).toList();
      if (req.isEmpty) continue;
      final score = used.length / req.length;
      if (score < minCoverage) continue;
      matches.add(RecipeMatch(recipe: r, score: score, missing: missing, used: used));
    }

    matches.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final byMissing = a.missing.length.compareTo(b.missing.length);
      if (byMissing != 0) return byMissing;
      return a.recipe.name.compareTo(b.recipe.name);
    });

    if (matches.length > maxResults) {
      return matches.sublist(0, maxResults);
    }
    return matches;
  }
}
