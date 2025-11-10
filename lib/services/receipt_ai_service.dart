import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class ReceiptAIService {
  final FirebaseFunctions _functions;

  ReceiptAIService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  /// Calls the callable Cloud Function 'nanonetsParseReceipt'.
  /// Provide either [imageUrl] or [imageFile]. Returns a list of ingredient candidates.
  Future<List<String>> parseWithNanonets({String? imageUrl, File? imageFile}) async {
    if (imageUrl == null && imageFile == null) {
      throw ArgumentError('Provide either imageUrl or imageFile');
    }
    String? base64;
    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      base64 = base64Encode(bytes);
    }

    final callable = _functions.httpsCallable('nanonetsParseReceipt');
    final resp = await callable.call({
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (base64 != null) 'imageBase64': base64,
    });
    final data = resp.data as Map;
    final list = (data['ingredients'] as List?)?.cast<String>() ?? const <String>[];
    return list;
  }

  /// Call a generic proxy endpoint (e.g., Cloudflare Worker/Vercel) that wraps Nanonets.
  /// Endpoint must accept JSON { imageUrl?: string, imageBase64?: string } and return { ingredients: string[] }.
  /// 
  /// IMPORTANTE: Nanonets procesa todo automáticamente (auto-approval). 
  /// No necesitamos esperar revisión humana - tomamos los datos que devuelve inmediatamente.
  Future<Map<String, dynamic>> parseWithProxy({String? endpoint, String? imageUrl, File? imageFile}) async {
    final url = endpoint ?? AppConfig.nanonetsProxyUrl;
    if (url.isEmpty) {
      throw ArgumentError('Proxy endpoint is empty. Set AppConfig.nanonetsProxyUrl');
    }
    String? base64;
    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      base64 = base64Encode(bytes);
    }

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
    
    // Siempre aceptamos los ingredientes que devuelve Nanonets
    // El modelo está configurado con auto-approval, así que los datos ya están validados
    return {
      'ingredients': list.cast<String>(),
      'count': list.length,
      'isEmpty': list.isEmpty,
    };
  }
}
