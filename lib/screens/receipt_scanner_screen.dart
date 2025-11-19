import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/ingredient.dart';
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
  String _rawText = '';
  List<String> _candidates = [];
  List<String> _normalized = [];
  List<Ingredient> _ingredientsWithQuantity = [];
  final _repo = PantryRepository();
  final _ai = ReceiptAIService();
  final commonUnits = ['unidad', 'g', 'kg', 'ml', 'l', 'cucharada', 'taza'];

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
      _ingredientsWithQuantity = [];
    });

    final inputImage = InputImage.fromFile(_image!);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    final text = recognizedText.text;
    final candidates = ReceiptParser.parse(text);
    final normalized = IngredientNormalizer.normalize(candidates);

    // Create Ingredient objects with default quantity/unit
    final ingredientsWithQty = normalized.map((name) => Ingredient(
      id: name.toLowerCase(),
      name: name,
      quantity: 1.0,
      unit: 'unidad',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      source: 'receipt',
    )).toList();

    setState(() {
      _loading = false;
      _rawText = text;
      _candidates = candidates;
      _normalized = normalized;
      _ingredientsWithQuantity = ingredientsWithQty;
    });
  }

  Future<void> _savePantry() async {
    if (_ingredientsWithQuantity.isEmpty) return;
    setState(() => _loading = true);
    
    // Save each ingredient with its quantity and unit
    for (final ingredient in _ingredientsWithQuantity) {
      await _repo.addItem(
        ingredient.name,
        quantity: ingredient.quantity,
        unit: ingredient.unit,
        source: 'receipt',
      );
    }
    
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_ingredientsWithQuantity.length} ingredientes guardados en tu alacena')),
      );
      // Reset state
      setState(() {
        _image = null;
        _normalized = [];
        _ingredientsWithQuantity = [];
        _rawText = '';
        _candidates = [];
      });
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
      
      // Create Ingredient objects with default quantity/unit
      final ingredientsWithQty = normalized.map((name) => Ingredient(
        id: name.toLowerCase(),
        name: name,
        quantity: 1.0,
        unit: 'unidad',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        source: 'receipt',
      )).toList();
      
      setState(() {
        _candidates = filtered;
        _normalized = normalized;
        _ingredientsWithQuantity = ingredientsWithQty;
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                    _ingredientsWithQuantity.isNotEmpty
                        ? Column(
                            children: _ingredientsWithQuantity
                                .asMap()
                                .entries
                                .map((entry) {
                              final index = entry.key;
                              final ing = entry.value;
                              return _IngredientEditTile(
                                ingredient: ing,
                                commonUnits: commonUnits,
                                onChanged: (updated) {
                                  setState(() {
                                    _ingredientsWithQuantity[index] = updated;
                                  });
                                },
                              );
                            }).toList(),
                          )
                        : Wrap(
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

/// Widget para editar cantidad y unidad de un ingrediente
class _IngredientEditTile extends StatefulWidget {
  final Ingredient ingredient;
  final List<String> commonUnits;
  final void Function(Ingredient) onChanged;

  const _IngredientEditTile({
    required this.ingredient,
    required this.commonUnits,
    required this.onChanged,
  });

  @override
  State<_IngredientEditTile> createState() => _IngredientEditTileState();
}

class _IngredientEditTileState extends State<_IngredientEditTile> {
  late TextEditingController _quantityController;
  late String _selectedUnit;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(text: widget.ingredient.quantity.toString());
    _selectedUnit = widget.ingredient.unit;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: AppTheme.primaryLight.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.ingredient.name,
              style: const TextStyle(
                color: AppTheme.foreground,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Cantidad input
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cantidad',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _quantityController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: '1',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        onChanged: (value) {
                          final qty = double.tryParse(value) ?? 1.0;
                          widget.onChanged(widget.ingredient.copyWith(quantity: qty));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Unidad dropdown
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Unidad',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButton<String>(
                        value: _selectedUnit,
                        isExpanded: true,
                        underline: Container(
                          height: 1,
                          color: AppTheme.primaryLight.withOpacity(0.3),
                        ),
                        items: widget.commonUnits
                            .map((unit) => DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit, style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedUnit = value);
                            widget.onChanged(widget.ingredient.copyWith(unit: value));
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
