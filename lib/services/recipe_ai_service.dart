import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

class RecipeAIService {
  final String endpoint;
  RecipeAIService({String? endpoint}) : endpoint = endpoint ?? AppConfig.recipesAiUrl;

  Future<List<Map<String, dynamic>>> generate({
    required List<String> ingredients,
    int max = 5,
    Map<String, dynamic>? prefs,
  }) async {
    if (endpoint.isEmpty) throw Exception('recipesAiUrl is empty');
    debugPrint('🔁 RecipeAIService.generate -> POST $endpoint');
    debugPrint('🔁 Payload: ${jsonEncode({
      'ingredients': ingredients,
      'max': max,
      if (prefs != null) 'prefs': prefs,
    })}');

    final resp = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'ingredients': ingredients,
        'max': max,
        if (prefs != null) 'prefs': prefs,
      }),
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
