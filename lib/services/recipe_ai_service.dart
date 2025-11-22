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
    int retryCount = 0,
  }) async {
    if (endpoint.isEmpty) throw Exception('recipesAiUrl is empty');
    debugPrint('🔁 RecipeAIService.generate -> POST $endpoint (intento ${retryCount + 1})');
    
    // Prepare ingredients list for the API
    final ingredientsList = ingredientsWithQuantity != null
        ? ingredientsWithQuantity.map((i) => '${i.quantity} ${i.unit} de ${i.name}').toList()
        : ingredients;
    
    final payload = {
      'ingredients': ingredientsList,
      'max': max,
      'includeQuantities': true,  // Tell AI to include quantities in recipes
      if (prefs != null) 'prefs': prefs,
    };
    
    debugPrint('🔁 Payload: ${jsonEncode(payload)}');

    final resp = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception('Timeout: El servidor tardó demasiado en responder');
      },
    );
    debugPrint('🔁 Response status: ${resp.statusCode}');
    debugPrint('🔁 Response body (first 500 chars): ${resp.body.substring(0, resp.body.length > 500 ? 500 : resp.body.length)}');

    // Handle error responses
    if (resp.statusCode >= 500) {
      // Server error - try to extract the raw JSON if available
      try {
        final errorData = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawJson = errorData['raw'] as String?;
        
        if (rawJson != null) {
          debugPrint('🔧 Intentando parsear JSON raw del error...');
          
          // Remove markdown code blocks if present
          String cleanJson = rawJson.trim();
          if (cleanJson.startsWith('```json')) {
            cleanJson = cleanJson.substring(7); // Remove ```json
          } else if (cleanJson.startsWith('```')) {
            cleanJson = cleanJson.substring(3); // Remove ```
          }
          if (cleanJson.endsWith('```')) {
            cleanJson = cleanJson.substring(0, cleanJson.length - 3);
          }
          cleanJson = cleanJson.trim();
          
          debugPrint('🔧 JSON limpio (primeros 300 chars): ${cleanJson.substring(0, cleanJson.length > 300 ? 300 : cleanJson.length)}');
          
          // Try to parse the cleaned JSON
          try {
            final data = jsonDecode(cleanJson) as Map<String, dynamic>;
            final list = (data['recipes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            
            if (list.isNotEmpty) {
              debugPrint('✅ Parseado exitoso: ${list.length} recetas recuperadas del error 502');
              return list;
            }
          } catch (parseError) {
            debugPrint('⚠️ JSON truncado o incompleto (error común del servidor): $parseError');
            // JSON is corrupted/truncated - this is a server-side issue
            // Fall through to throw user-friendly error below
          }
        }
      } catch (e) {
        debugPrint('⚠️ No se pudo recuperar del error 502: $e');
      }
      
      // Retry logic for 502 errors (max 2 retries)
      if (retryCount < 2) {
        debugPrint('⚠️ Error 502, reintentando (${retryCount + 1}/2)...');
        await Future.delayed(Duration(seconds: retryCount + 1)); // Wait 1s, then 2s
        return generate(
          ingredients: ingredients,
          ingredientsWithQuantity: ingredientsWithQuantity,
          max: max,
          prefs: prefs,
          retryCount: retryCount + 1,
        );
      }
      
      // User-friendly error message after retries exhausted
      throw Exception('El servidor está teniendo problemas. Ya intentamos ${retryCount + 1} veces. Por favor intenta más tarde.');
    }
    
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Error del servidor (${resp.statusCode}). Por favor intenta de nuevo.');
    }
    
    // Parse successful response
    String responseBody = resp.body.trim();
    
    // Remove markdown code blocks if present
    if (responseBody.startsWith('```json')) {
      responseBody = responseBody.substring(7);
    } else if (responseBody.startsWith('```')) {
      responseBody = responseBody.substring(3);
    }
    if (responseBody.endsWith('```')) {
      responseBody = responseBody.substring(0, responseBody.length - 3);
    }
    responseBody = responseBody.trim();
    
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    final list = (data['recipes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    
    debugPrint('✅ ${list.length} recetas generadas');
    return list;
  }
}
