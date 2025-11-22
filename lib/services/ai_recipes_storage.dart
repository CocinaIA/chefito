import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to persist AI-generated recipes using SharedPreferences
/// Works on all platforms (web, mobile, desktop)
class AIRecipesStorage {
  static const _key = 'chefito_ai_recipes';

  /// Save AI recipes to storage
  static Future<void> saveRecipes(List<Map<String, dynamic>> recipes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(recipes);
      await prefs.setString(_key, json);
      debugPrint('💾 Guardadas ${recipes.length} recetas IA ✨');
    } catch (e) {
      debugPrint('❌ Error al guardar recetas: $e');
    }
  }

  /// Load AI recipes from storage
  static Future<List<Map<String, dynamic>>> loadRecipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key);
      if (json == null || json.isEmpty) return [];
      
      final decoded = jsonDecode(json) as List;
      final recipes = decoded.cast<Map<String, dynamic>>();
      debugPrint('📂 Cargadas ${recipes.length} recetas IA 📖');
      return recipes;
    } catch (e) {
      debugPrint('❌ Error al cargar recetas: $e');
      return [];
    }
  }

  /// Clear AI recipes from storage
  static Future<void> clearRecipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      debugPrint('🗑️ Recetas IA eliminadas 👋');
    } catch (e) {
      debugPrint('❌ Error al limpiar recetas: $e');
    }
  }
}
