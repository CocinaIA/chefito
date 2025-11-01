import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';

class ReceiptAIService {
  /// Call a generic proxy endpoint (e.g., Cloudflare Worker) that wraps Nanonets.
  /// Returns a map with ingredients list and metadata
  Future<Map<String, dynamic>> parseWithProxy({
    String? endpoint, 
    String? imageUrl, 
    File? imageFile
  }) async {
    final url = endpoint ?? AppConfig.nanonetsProxyUrl;
    
    // Si no hay proxy configurado, devolver resultado vacío
    if (url.isEmpty) {
      return {
        'ingredients': <String>[],
        'needsReview': false,
        'isEmpty': true,
        'error': 'No proxy configured'
      };
    }
    
    String? base64;
    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      base64 = base64Encode(bytes);
    }

    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (base64 != null) 'imageBase64': base64,
        }),
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('Proxy error: ${resp.statusCode} ${resp.body}');
      }
      
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['ingredients'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
      
      // Check if the response indicates pending human review
      final raw = data['raw'] as Map<String, dynamic>?;
      final results = raw?['result'] as List?;
      bool needsReview = false;
      
      if (results != null && results.isNotEmpty) {
        for (var r in results) {
          if (r is Map && r['message']?.toString().toLowerCase().contains('pending') == true) {
            needsReview = true;
            break;
          }
        }
      }
      
      return {
        'ingredients': list.cast<String>(),
        'needsReview': needsReview,
        'isEmpty': list.isEmpty,
      };
    } catch (e) {
      return {
        'ingredients': <String>[],
        'needsReview': false,
        'isEmpty': true,
        'error': e.toString()
      };
    }
  }
}