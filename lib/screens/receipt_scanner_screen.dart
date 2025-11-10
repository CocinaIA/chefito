import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../services/receipt_parser.dart';
import '../services/ingredient_normalizer.dart';
import '../services/pantry_repository.dart';
import '../services/receipt_ai_service.dart';
import '../config.dart';
import '../theme.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  File? _image;
  bool _loading = false;
  bool _advancedLoading = false;
  List<String> _normalized = [];
  final _repo = PantryRepository();
  final _ai = ReceiptAIService();

  @override
  void initState() {
    super.initState();
    // Iniciar escaneo automáticamente al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImage();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) {
      // Si el usuario cancela, volver atrás
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _image = File(picked.path));
    await _runOcr();
  }

  Future<void> _runOcr() async {
    if (_image == null) return;
    setState(() {
      _loading = true;
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
    setState(() => _advancedLoading = true);
    try {
      final result = await _ai.parseWithProxy(imageFile: _image!);
      final aiCandidates = (result['ingredients'] as List).cast<String>();
      
      // Si Nanonets no encontró nada, hacer fallback a OCR local
      if (aiCandidates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Nanonets no detectó ingredientes. Usando OCR local...'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        await _runOcr();
        return;
      }
      
      // Procesar los ingredientes detectados
      final filtered = ReceiptParser.cleanCandidates(aiCandidates);
      final normalized = IngredientNormalizer.normalize(filtered);
      
      setState(() {
        _normalized = normalized;
      });
      
      if (mounted) {
        if (normalized.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('✓ ${normalized.length} ingredientes con IA Avanzada'),
                ],
              ),
              backgroundColor: AppTheme.primary,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ No se detectaron ingredientes válidos'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en escaneo avanzado: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _advancedLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Escanear ticket',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: _loading ? null : _pickImage,
        icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
        label: const Text(
          'Escanear',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Procesando ticket...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner de instrucciones
                  if (_image == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primary.withOpacity(0.1),
                            AppTheme.primaryLight.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '🧾',
                            style: TextStyle(fontSize: 44),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Escanea tus compras',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppTheme.foreground,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Captura una foto del ticket y extrae automáticamente todos los ingredientes',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Text('💡', style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Para mejores resultados, asegúrate de que el ticket sea legible',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_image != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Ticket capturado',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.foreground,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _image!,
                        height: 240,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],

                  if (_normalized.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          'Ingredientes detectados',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.foreground,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_normalized.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _normalized
                          .map((e) => Chip(
                                label: Text(
                                  e,
                                  style: const TextStyle(
                                    color: AppTheme.foreground,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                backgroundColor: AppTheme.primaryLight.withOpacity(0.2),
                                side: BorderSide(
                                  color: AppTheme.primaryLight.withOpacity(0.4),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _savePantry,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'Guardar en mi alacena',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ] else if (_candidates.isNotEmpty && _normalized.isEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '⚠️ Candidatos detectados (requieren validación)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._candidates
                              .map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      '• $e',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ],
                      ),
                    ),
                  ],

                  if (_image != null && _normalized.isEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _runNanonets,
                          icon: const Icon(Icons.cloud_rounded),
                          label: const Text('Usar IA'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        if (AppConfig.nanonetsProxyUrl.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _runProxy,
                            icon: const Icon(Icons.cloud_queue_rounded),
                            label: const Text('Nanonets'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary.withOpacity(0.7),
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
