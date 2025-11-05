import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ingredient.dart';
import '../services/database_helper.dart';

class PantryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  
  // StreamController para notificar cambios
  final StreamController<List<String>> _pantryController = StreamController<List<String>>.broadcast();

  Future<void> addItems(List<String> names, {String source = 'receipt'}) async {
    debugPrint('🗃️ PantryRepository.addItems called with ${names.length} items');
    
    final now = DateTime.now();
    for (final name in names) {
      if (name.trim().isEmpty) continue;
      
      final normalizedName = name.toLowerCase().trim();
      debugPrint('🗃️ Adding item: $normalizedName');
      
      final ingredient = Ingredient(
        name: normalizedName,
        source: source,
        createdAt: now,
        updatedAt: now,
      );
      
      try {
        await _dbHelper.insertIngredient(ingredient);
        debugPrint('✅ Item added: $normalizedName');
      } catch (e) {
        debugPrint('❌ Error adding item $normalizedName: $e');
      }
    }
    
    // Notificar cambios
    _notifyPantryChanged();
    debugPrint('✅ Batch add completed successfully!');
  }

  Future<void> addItem(String name, {String source = 'manual'}) async {
    if (name.trim().isEmpty) return;
    
    final normalizedName = name.toLowerCase().trim();
    final now = DateTime.now();
    
    final ingredient = Ingredient(
      name: normalizedName,
      source: source,
      createdAt: now,
      updatedAt: now,
    );
    
    await _dbHelper.insertIngredient(ingredient);
    _notifyPantryChanged();
  }

  Future<void> removeItem(String name) async {
    final normalizedName = name.toLowerCase().trim();
    await _dbHelper.deleteIngredientByName(normalizedName);
    _notifyPantryChanged();
  }

  Stream<List<String>> streamPantry() {
    // Emitir lista inicial
    _notifyPantryChanged();
    return _pantryController.stream;
  }

  Future<List<String>> getAllItems() async {
    final ingredients = await _dbHelper.getAllIngredients();
    return ingredients.map((ingredient) => ingredient.name).toList();
  }

  Future<List<String>> searchItems(String query) async {
    final ingredients = await _dbHelper.searchIngredients(query);
    return ingredients.map((ingredient) => ingredient.name).toList();
  }

  Future<int> getItemsCount() async {
    return await _dbHelper.getIngredientsCount();
  }

  Future<void> clearPantry() async {
    await _dbHelper.clearAllIngredients();
    _notifyPantryChanged();
  }

  Future<void> _notifyPantryChanged() async {
    try {
      final items = await getAllItems();
      if (!_pantryController.isClosed) {
        _pantryController.add(items);
      }
    } catch (e) {
      debugPrint('Error notifying pantry changes: $e');
    }
  }

  void dispose() {
    _pantryController.close();
  }
}