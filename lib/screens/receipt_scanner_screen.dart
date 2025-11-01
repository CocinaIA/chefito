import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

  @override
  void dispose() {
    _repo.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    
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

    try {
      final inputImage = InputImage.fromFile(_image!);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      final text = recognizedText.text;
      final candidates = ReceiptParser.parse(text);
      final normalized = IngredientNormalizer.normalize(candidates);

      setState(() {
        _rawText = text;
        _candidates = candidates;
        _normalized = normalized;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error en OCR: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _savePantry() async {
    if (_normalized.isEmpty) return;
    
    setState(() => _loading = true);
    try {
      await _repo.addItems(_normalized, source: 'receipt');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_normalized.length} ingredientes guardados en tu alacena'),
            action: SnackBarAction(
              label: 'Ver alacena',
              onPressed: () => Navigator.pushNamed(context, '/pantry'),
            ),
          ),
        );
        // Limpiar la pantalla después de guardar
        setState(() {
          _image = null;
          _rawText = '';
          _candidates = [];
          _normalized = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _runProxy() async {
    if (_image == null) return;
    
    if (AppConfig.nanonetsProxyUrl.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Proxy de Nanonets no configurado. Usando OCR local.'),
          ),
        );
      }
      return;
    }
    
    setState(() => _loading = true);
    
    try {
      final result = await _ai.parseWithProxy(imageFile: _image!);
      
      if (result.containsKey('error')) {
        throw Exception(result['error']);
      }
      
      final aiCandidates = (result['ingredients'] as List).cast<String>();
      final needsReview = result['needsReview'] as bool? ?? false;
      final isEmpty = result['isEmpty'] as bool? ?? true;
      
      if (needsReview || (isEmpty && aiCandidates.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Nanonets requiere revisión humana. Usando OCR local.'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de Nanonets: $e. Usando OCR local.')),
        );
        // Fall back to local OCR
        await _runOcr();
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildImagePreview() {
    if (_image == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: kIsWeb 
          ? Image.network(_image!.path, height: 200, fit: BoxFit.cover)
          : Image.file(_image!, height: 200, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_image == null) return const SizedBox.shrink();
    
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: _loading ? null : _runOcr,
          icon: const Icon(Icons.text_fields),
          label: const Text('OCR Local'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[600],
            foregroundColor: Colors.white,
          ),
        ),
        if (AppConfig.nanonetsProxyUrl.isNotEmpty)
          ElevatedButton.icon(
            onPressed: _loading ? null : _runProxy,
            icon: const Icon(Icons.cloud_queue),
            label: const Text('Nanonets IA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );
  }

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Procesando imagen...'),
          ],
        ),
      );
    }
    
    if (_normalized.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ingredientes detectados (${_normalized.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _savePantry,
                icon: const Icon(Icons.save),
                label: const Text('Guardar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _normalized
                .map((ingredient) => Chip(
                      label: Text(ingredient),
                      backgroundColor: Colors.green[100],
                      labelStyle: TextStyle(color: Colors.green[800]),
                    ))
                .toList(),
          ),
        ],
      );
    }
    
    if (_candidates.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Candidatos encontrados:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _candidates.map((candidate) => 
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('• $candidate'),
              ),
            ).toList(),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildDebugInfo() {
    if (_rawText.isEmpty) return const SizedBox.shrink();
    
    return ExpansionTile(
      title: const Text('Texto OCR completo (debug)'),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _rawText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear ticket'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/pantry'),
            icon: const Icon(Icons.kitchen),
            tooltip: 'Ver alacena',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImage,
        icon: const Icon(Icons.camera_alt),
        label: Text(kIsWeb ? 'Seleccionar imagen' : 'Tomar foto'),
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instrucciones
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[600]),
                      const SizedBox(width: 8),
                      Text(
                        '¿Cómo usar?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kIsWeb 
                      ? '1. Selecciona una imagen de tu ticket de compra\n2. La app extraerá automáticamente los ingredientes\n3. Guarda los ingredientes en tu alacena'
                      : '1. Toma una foto clara de tu ticket de compra\n2. La app extraerá automáticamente los ingredientes\n3. Guarda los ingredientes en tu alacena',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Vista previa de la imagen
            _buildImagePreview(),
            
            // Botones de acción
            _buildActionButtons(),
            const SizedBox(height: 20),
            
            // Resultados
            _buildResults(),
            const SizedBox(height: 20),
            
            // Información de debug
            _buildDebugInfo(),
          ],
        ),
      ),
    );
  }
}