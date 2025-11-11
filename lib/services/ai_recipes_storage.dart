import 'dart:convert';
import 'package:flutter/foundation.dart';

// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Service to persist AI-generated recipes using browser localStorage
/// Only works on web platform
class AIRecipesStorage {
  static const _key = 'chefito_ai_recipes';

  /// Save AI recipes to browser localStorage (web only)
  static Future<void> saveRecipes(List<Map<String, dynamic>> recipes) async {
    try {
      if (!kIsWeb) return;
      
      final json = jsonEncode(recipes);
      html.window.localStorage[_key] = json;
      debugPrint('💾 Guardadas ${recipes.length} recetas IA ✨');
    } catch (e) {
      debugPrint('❌ Error al guardar recetas: $e');
    }
  }

  /// Load AI recipes from browser localStorage (web only)
  static Future<List<Map<String, dynamic>>> loadRecipes() async {
    try {
      if (!kIsWeb) return [];
      
      final json = html.window.localStorage[_key];
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

  /// Clear AI recipes from browser localStorage (web only)
  static Future<void> clearRecipes() async {
    try {
      if (!kIsWeb) return;
      
      html.window.localStorage.remove(_key);
      debugPrint('🗑️ Recetas IA eliminadas 👋');
    } catch (e) {
      debugPrint('❌ Error al limpiar recetas: $e');
    }
  }
}
