import 'package:flutter_test/flutter_test.dart';
import 'package:chefito/services/recipe_recommender.dart';

void main() {
  test('Recommender ranks recipes by coverage', () {
    final pantry = ['pasta', 'tomate', 'aceite', 'sal'];
    final out = RecipeRecommender.recommend(pantry: pantry, minCoverage: 0.4);
    expect(out.isNotEmpty, true);
    // Pasta con salsa de tomate should be first with high coverage
    expect(out.first.recipe.id, 'pasta-tomate');
    expect(out.first.used.contains('pasta'), true);
    expect(out.first.score, greaterThan(0.6));
  });

  test('Filters below minCoverage', () {
    final pantry = ['agua'];
    final out = RecipeRecommender.recommend(pantry: pantry, minCoverage: 0.6);
    expect(out.isEmpty, true);
  });
}
