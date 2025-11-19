import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/ingredient.dart';

class RecipeAIService {
  final String endpoint;
  RecipeAIService({String? endpoint}) : endpoint = endpoint ?? AppConfig.recipesAiUrl;

  Future<List<Map<String, dynamic>>> generate({
    required List<String> ingredients,
    List<Ingredient>? ingredientsWithQuantity,
    int max = 5,
    Map<String, dynamic>? prefs,
  }) async {
    if (endpoint.isEmpty) throw Exception('recipesAiUrl is empty');
    debugPrint('🔁 RecipeAIService.generate -> POST $endpoint');
    
    // Prepare ingredients list for the API
    final ingredientsList = ingredientsWithQuantity != null
        ? ingredientsWithQuantity.map((i) => '${i.quantity} ${i.unit} de ${i.name}').toList()
        : ingredients;
    
    final payload = {
      'ingredients': ingredientsList,
      'max': max,
      if (prefs != null) 'prefs': prefs,
    };
    
    debugPrint('🔁 Payload: ${jsonEncode(payload)}');

    final resp = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    debugPrint('🔁 Response status: ${resp.statusCode}');
    debugPrint('🔁 Response body: ${resp.body}');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('AI error ${resp.statusCode}: ${resp.body}');
    }
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (data['recipes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return list;
  }
}
