import 'package:flutter/material.dart';

import '../services/pantry_repository.dart';
import '../services/ingredient_normalizer.dart';
import '../services/receipt_parser.dart';
import '../theme.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

/// Helper to expand unit abbreviations to full names
String _expandUnit(String unit) {
  if (unit.isEmpty) return '';
  
  final unitMap = {
    'g': 'gramos',
    'kg': 'kilogramos',
    'ml': 'mililitros',
    'l': 'litros',
    'cucharada': 'cucharadas',
    'taza': 'tazas',
    'unidad': 'unidad',
  };
  
  final lowerUnit = unit.toLowerCase().trim();
  return unitMap[lowerUnit] ?? unit;
}

/// Helper to parse ingredient string and extract quantity/unit
Map<String, String> _parseIngredientDisplay(String ingredient) {
  // Try to match patterns like "50 g arroz", "3 unidad tomate", etc.
  // Pattern: "quantity unit name" or just "name"
  final match = RegExp(r'^(\d+(?:\.\d+)?)\s+([a-záéíóúñ\s]*?)\s+(.+)$').firstMatch(ingredient.trim());
  
  if (match != null) {
    return {
      'quantity': match.group(1)?.trim() ?? '',
      'unit': match.group(2)?.trim() ?? '',
      'name': match.group(3)?.trim() ?? ingredient,
    };
  }
  
  return {'name': ingredient, 'quantity': '', 'unit': ''};
}

class _PantryScreenState extends State<PantryScreen> {
  final _repo = PantryRepository();

  Future<void> _cleanPantry() async {
    final all = await _repo.getAllItems();
    // Reutilizar el filtro del parser para detectar ruido (admin/ciudad/etc.)
    final cleaned = ReceiptParser.cleanCandidates(all);
    final keep = IngredientNormalizer.normalize(cleaned).toSet();
    final toDelete = all.where((e) => !keep.contains(e.toLowerCase())).toList();

    for (final name in toDelete) {
      await _repo.removeItem(name);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Limpieza completada: ${toDelete.length} elementos eliminados')),
    );
  }

  Future<void> _addManually() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    String selectedUnit = 'unidad';
    
    final commonUnits = ['unidad', 'g', 'kg', 'ml', 'l', 'cucharada', 'taza'];
    
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Agregar ingrediente'),
          contentPadding: const EdgeInsets.all(20),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingrediente',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Ej. tomate, cebolla, arroz',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cantidad',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: 'Ej. 500, 2.5, 1',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unidad de medida',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: selectedUnit,
                  isExpanded: true,
                  items: commonUnits
                      .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
                      .toList(),
                  onChanged: (value) {
                    setState(() => selectedUnit = value ?? 'unidad');
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'name': nameController.text,
                'quantity': double.tryParse(quantityController.text) ?? 1.0,
                'unit': selectedUnit,
              }),
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
    
    if (result == null || result['name'].isEmpty) return;
    
    final normalized = IngredientNormalizer.normalize([result['name']]);
    if (normalized.isEmpty) return;
    
    // Guardar con cantidad y unidad separados
    await _repo.addItem(
      normalized.first,
      quantity: result['quantity'] as double,
      unit: result['unit'] as String,
    );
  }

  /// Build widget to display ingredient with separated quantity and unit
  Widget _buildIngredientDisplay(String ingredient) {
    final parts = _parseIngredientDisplay(ingredient);
    final name = parts['name'] ?? ingredient;
    final quantity = parts['quantity'] ?? '';
    final unit = parts['unit'] ?? '';
    final hasQuantity = quantity.isNotEmpty;

    if (!hasQuantity) {
      return Text(
        name,
        style: const TextStyle(
          color: AppTheme.foreground,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      );
    }

    // Expand unit abbreviations (g -> gramos, ml -> mililitros, etc)
    final expandedUnit = _expandUnit(unit);

    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: AppTheme.foreground,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            '$quantity $expandedUnit'.trim(),
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _remove(String name) async {
    await _repo.removeItem(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Eliminado: $name')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi alacena',
          style: TextStyle(
            color: AppTheme.foreground,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Limpiar ruido',
            onPressed: _cleanPantry,
            icon: const Icon(Icons.cleaning_services_outlined, color: AppTheme.primary),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _addManually,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<String>>(
        stream: _repo.streamPantry(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.kitchen,
                    size: 64,
                    color: AppTheme.primaryLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu alacena está vacía',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppTheme.foreground,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Agrega ingredientes manualmente o escanea un ticket',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final name = items[index];
              return Dismissible(
                key: ValueKey(name),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _remove(name),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: AppTheme.primaryLight.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Icon(
                      Icons.check_circle,
                      color: AppTheme.primary,
                      size: 24,
                    ),
                    title: _buildIngredientDisplay(name),
                    trailing: Icon(
                      Icons.swipe_left,
                      color: AppTheme.textSecondary.withOpacity(0.5),
                      size: 18,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
