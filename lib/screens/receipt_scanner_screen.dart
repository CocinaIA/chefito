import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../services/receipt_parser.dart';
import '../services/ingredient_normalizer.dart';
import '../services/pantry_repository.dart';
import '../services/receipt_ai_service.dart';
import '../config.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  File? _image;
  bool _loading = false;
  String _rawText = '';
  List<String> _candidates = [];
  List<String> _normalized = [];
  final _repo = PantryRepository();
  final _ai = ReceiptAIService();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;
    setState(() => _image = File(picked.path));
    await _runOcr();
  }

  Future<void> _runOcr() async {
    if (_image == null) return;
    setState(() {
      _loading = true;
      _rawText = '';
      _candidates = [];
      _normalized = [];
    });

    final inputImage = InputImage.fromFile(_image!);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final text = recognizedText.text;
    final candidates = ReceiptParser.parse(text);
    final normalized = IngredientNormalizer.normalize(candidates);

    setState(() {
      _loading = false;
      _rawText = text;
      _candidates = candidates;
      _normalized = normalized;
    });
  }

  Future<void> _savePantry() async {
    if (_normalized.isEmpty) return;
    setState(() => _loading = true);
    await _repo.addItems(_normalized, source: 'receipt');
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingredientes guardados en tu alacena')),
      );
    }
  }

  Future<void> _runNanonets() async {
    if (_image == null) return;
    setState(() => _loading = true);
    try {
      final aiCandidates = await _ai.parseWithNanonets(imageFile: _image!);
      // Filtrar ruido administrativo de la salida del AI
      final filtered = ReceiptParser.cleanCandidates(aiCandidates);
      final normalized = IngredientNormalizer.normalize(filtered);
      setState(() {
        _candidates = filtered;
        _normalized = normalized;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Nanonets falló: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runProxy() async {
    if (_image == null) return;
    if (AppConfig.nanonetsProxyUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configura AppConfig.nanonetsProxyUrl para usar el proxy')),
        );
      }
      return;
    }
    setState(() => _loading = true);
    try {
  final result = await _ai.parseWithProxy(imageFile: _image!);
  final aiCandidates = (result['ingredients'] as List).cast<String>();
      final needsReview = result['needsReview'] as bool? ?? false;
      final isEmpty = result['isEmpty'] as bool? ?? true;
      
      if (needsReview || (isEmpty && aiCandidates.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Nanonets requiere revisión humana. Usa el OCR local mientras tanto.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        // Fall back to local OCR
        await _runOcr();
        return;
      }
      
      final filtered = ReceiptParser.cleanCandidates(aiCandidates);
      final normalized = IngredientNormalizer.normalize(filtered);
      setState(() {
        _candidates = filtered;
        _normalized = normalized;
      });
      
      if (mounted && normalized.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ ${normalized.length} ingredientes detectados con Nanonets')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Proxy falló: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear ticket')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImage,
        icon: const Icon(Icons.receipt_long),
        label: const Text('Escanear'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_image!, height: 200, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 16),
                  if (_normalized.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Ingredientes detectados',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _savePantry,
                          icon: const Icon(Icons.save),
                          label: const Text('Guardar'),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _normalized
                          .map((e) => Chip(label: Text(e)))
                          .toList(),
                    ),
                  ] else if (_candidates.isNotEmpty) ...[
                    const Text('Candidatos (antes de normalizar):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ..._candidates.map((e) => Text('• $e')),
                  ] else ...[
                    const Text('Toma una foto del ticket para extraer los ingredientes.'),
                  ],
                  const SizedBox(height: 16),
                  if (_image != null)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _runNanonets,
                          icon: const Icon(Icons.cloud),
                          label: const Text('Usar Nanonets (Function)'),
                        ),
                        if (AppConfig.nanonetsProxyUrl.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _runProxy,
                            icon: const Icon(Icons.cloud_queue),
                            label: const Text('Usar Nanonets (Proxy)'),
                          ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  if (_rawText.isNotEmpty) ...[
                    const Text('Texto OCR (depuración):',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      _rawText,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
