import 'dart:convert';
import 'package:flutter/foundation.dart';

class InventoryService {
  static const String _storageKey = 'chefito_inventory';
  
  List<String> _ingredients = [
    'arroz',
    'pollo',
    'cebolla',
    'tomate',
    'ajo',
    'aceite de oliva',
    'sal',
    'pimienta'
  ];

  List<String> get ingredients => List.unmodifiable(_ingredients);

  void addIngredient(String ingredient) {
    if (!_ingredients.contains(ingredient.toLowerCase())) {
      _ingredients.add(ingredient.toLowerCase());
      _saveToStorage();
    }
  }

  void removeIngredient(String ingredient) {
    _ingredients.remove(ingredient.toLowerCase());
    _saveToStorage();
  }

  void clearInventory() {
    _ingredients.clear();
    _saveToStorage();
  }

  void _saveToStorage() {
    if (kIsWeb) {
      // En web usaríamos localStorage, aquí simulamos
      debugPrint('Guardando inventario: $_ingredients');
    }
  }

  void _loadFromStorage() {
    if (kIsWeb) {
      // En web cargaríamos desde localStorage
      debugPrint('Cargando inventario desde storage');
    }
  }

  // Simular escaneo de ticket
  List<String> simulateReceiptScan() {
    final newIngredients = [
      'pasta',
      'queso',
      'jamón',
      'leche',
      'huevos',
      'pan'
    ];
    
    for (final ingredient in newIngredients) {
      addIngredient(ingredient);
    }
    
    return newIngredients;
  }
}