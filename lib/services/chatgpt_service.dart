import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class ChatGPTService {
  static const String _apiUrl = AppConfig.openAIApiUrl;
  static const String _apiKey = AppConfig.openAIApiKey;

  Future<Map<String, dynamic>> getRecipeSuggestions(List<String> ingredients) async {
    if (_apiKey.isEmpty) {
      // Simulación para demo
      return _getSimulatedRecipe(ingredients);
    }

    try {
      final prompt = _buildRecipePrompt(ingredients);
      
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-3.5-turbo',
          'messages': [
            {
              'role': 'system',
              'content': 'Eres un chef experto que sugiere recetas basadas en ingredientes disponibles. Responde en formato JSON con: nombre, descripción, ingredientes_usados, ingredientes_faltantes, pasos, tiempo_preparacion, dificultad, video_sugerido.'
            },
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'max_tokens': 1000,
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return jsonDecode(content);
      } else {
        throw Exception('Error en API de OpenAI: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback a simulación en caso de error
      return _getSimulatedRecipe(ingredients);
    }
  }

  String _buildRecipePrompt(List<String> ingredients) {
    return '''
Tengo estos ingredientes disponibles: ${ingredients.join(', ')}.
Por favor sugiere una receta que pueda hacer con estos ingredientes.
Si faltan algunos ingredientes (máximo 4), inclúyelos en "ingredientes_faltantes".
Responde en formato JSON válido con esta estructura:
{
  "nombre": "Nombre de la receta",
  "descripcion": "Breve descripción",
  "ingredientes_usados": ["ingrediente1", "ingrediente2"],
  "ingredientes_faltantes": ["ingrediente3"],
  "pasos": ["Paso 1", "Paso 2", "Paso 3"],
  "tiempo_preparacion": "30 minutos",
  "dificultad": "Fácil",
  "video_sugerido": "https://www.youtube.com/watch?v=ejemplo"
}
    ''';
  }

  Map<String, dynamic> _getSimulatedRecipe(List<String> ingredients) {
    // Simulación para demo cuando no hay API key
    final recipes = [
      {
        "nombre": "Arroz con Pollo Casero",
        "descripcion": "Un delicioso arroz con pollo tradicional, perfecto para cualquier ocasión.",
        "ingredientes_usados": ingredients.take(4).toList(),
        "ingredientes_faltantes": ["azafrán", "guisantes"],
        "pasos": [
          "Sofríe la cebolla y el ajo en aceite caliente",
          "Agrega el pollo cortado en trozos y cocina hasta dorar",
          "Incorpora el tomate y cocina por 5 minutos",
          "Añade el arroz y mezcla bien",
          "Agrega caldo caliente y deja cocinar 18 minutos",
          "Deja reposar 5 minutos antes de servir"
        ],
        "tiempo_preparacion": "45 minutos",
        "dificultad": "Fácil",
        "video_sugerido": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      },
      {
        "nombre": "Pasta con Verduras",
        "descripcion": "Una pasta fresca y saludable con las verduras que tienes disponibles.",
        "ingredientes_usados": ingredients.take(3).toList(),
        "ingredientes_faltantes": ["pasta", "queso parmesano"],
        "pasos": [
          "Hierve agua con sal para la pasta",
          "Corta las verduras en trozos pequeños",
          "Sofríe las verduras en aceite de oliva",
          "Cocina la pasta según las instrucciones",
          "Mezcla la pasta con las verduras",
          "Sirve con queso rallado"
        ],
        "tiempo_preparacion": "25 minutos",
        "dificultad": "Muy Fácil",
        "video_sugerido": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
      }
    ];

    return recipes[DateTime.now().millisecond % recipes.length];
  }
}