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
        title: const Text('Escanear Ticket'),
        backgroundColor: AppTheme.background,
        actions: [
          IconButton(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Tomar otra foto',
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    'Analizando ticket...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
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
                  // Imagen del ticket
                  if (_image != null)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          _image!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Resultados
                  if (_normalized.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ingredientes detectados',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.foreground,
                                ),
                              ),
                              Text(
                                '${_normalized.length} encontrados',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Chips de ingredientes
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _normalized.map((ingredient) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppTheme.primary.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            ingredient,
                            style: TextStyle(
                              color: AppTheme.foreground,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Botón de guardar
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _savePantry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.save, size: 20),
                        label: const Text(
                          'Guardar en Mi Alacena',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Botón de escaneo avanzado
                    if (AppConfig.nanonetsProxyUrl.isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _advancedLoading ? null : _runProxy,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: BorderSide(color: AppTheme.primary.withOpacity(0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _advancedLoading
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome, size: 18),
                          label: Text(
                            _advancedLoading
                                ? 'Analizando con IA...'
                                : 'Escaneo Avanzado (IA)',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ] else if (_image != null) ...[
                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 48,
                            color: AppTheme.textSecondary.withOpacity(0.5),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No se detectaron ingredientes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Intenta con otra foto más clara',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textSecondary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
