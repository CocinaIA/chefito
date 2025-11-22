import 'package:flutter/material.dart';

import '../models/ingredient.dart';
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

class _PantryScreenState extends State<PantryScreen> {
  final _repo = PantryRepository();

  Future<void> _cleanPantry() async {
    // Get all ingredients to analyze
    final allIngredients = await _repo.getAllIngredients();
    
    if (allIngredients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La alacena está vacía')),
        );
      }
      return;
    }
    
    // Get just the names for cleaning analysis
    final allNames = allIngredients.map((ing) => ing.name).toList();
    
    // Use parser to detect noise (admin/ciudad/etc.)
    final cleaned = ReceiptParser.cleanCandidates(allNames);
    final keep = IngredientNormalizer.normalize(cleaned).toSet();
    
    // Find ingredients to delete (noise items)
    final toDelete = allIngredients
        .where((ing) => !keep.contains(ing.name.toLowerCase()))
        .toList();

    if (toDelete.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ No hay elementos para limpiar')),
        );
      }
      return;
    }

    // Show confirmation dialog
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Text('¿Limpiar alacena?'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se eliminarán ${toDelete.length} elementos que parecen ruido o datos incorrectos:',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: toDelete.map((ing) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.close, color: Colors.red.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ing.display,
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Esta acción no se puede deshacer.',
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, limpiar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Execute deletion
    for (final ingredient in toDelete) {
      await _repo.removeItem(ingredient.name);
    }
    
    if (mounted) {
      setState(() {}); // Refresh the UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Limpieza completada: ${toDelete.length} elementos eliminados'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _addManually() async {
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');
    String selectedUnit = 'unidad';
    
    // Unidades con nombre corto (para almacenamiento) y nombre largo (para display)
    final unitOptions = {
      'unidad': 'unidad',
      'g': 'gramos',
      'kg': 'kilogramos',
      'ml': 'mililitros',
      'l': 'litros',
      'cucharada': 'cucharadas',
      'taza': 'tazas',
    };
    
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
                  items: unitOptions.entries
                      .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
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
  Widget _buildIngredientTile(Ingredient ingredient) {
    final expandedUnit = _expandUnit(ingredient.unit);
    final quantityText = ingredient.quantity % 1 == 0 
        ? ingredient.quantity.toInt().toString() 
        : ingredient.quantity.toString();

    return Row(
      children: [
        Expanded(
          child: Text(
            ingredient.name,
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
            '$quantityText $expandedUnit'.trim(),
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

  Future<void> _editIngredient(Ingredient ingredient) async {
    final nameController = TextEditingController(text: ingredient.name);
    final quantityController = TextEditingController(
      text: ingredient.quantity % 1 == 0 
          ? ingredient.quantity.toInt().toString() 
          : ingredient.quantity.toString()
    );
    String selectedUnit = ingredient.unit;
    
    final unitOptions = {
      'unidad': 'unidad',
      'g': 'gramos',
      'kg': 'kilogramos',
      'ml': 'mililitros',
      'l': 'litros',
      'cucharada': 'cucharadas',
      'taza': 'tazas',
    };
    
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar ingrediente'),
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
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'ej: Arroz, Huevos',
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
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '1',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Unidad',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedUnit,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  items: unitOptions.entries
                      .map((entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ))
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
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    
    if (result == null || result['name'].isEmpty) return;
    
    // Actualizar el ingrediente
    await _repo.addItem(
      result['name'] as String,
      quantity: result['quantity'] as double,
      unit: result['unit'] as String,
    );
    
    if (mounted) {
      setState(() {});
    }
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
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'clean_noise') {
                await _cleanPantry();
              } else if (value == 'delete_all') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('¿Vaciar alacena?'),
                    content: const Text('Se eliminarán TODOS los ingredientes. Esta acción no se puede deshacer.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sí, vaciar'),
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  final all = await _repo.getAllIngredients();
                  for (final item in all) {
                    await _repo.removeItem(item.name);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Alacena vaciada correctamente')),
                    );
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clean_noise',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_outlined, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Limpiar ruido (OCR)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Vaciar alacena', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _addManually,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Ingredient>>(
        stream: _repo.streamPantryIngredients(),
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
              final item = items[index];
              return Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) => _remove(item.name),
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppTheme.primaryLight.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.restaurant,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    title: _buildIngredientTile(item),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      color: AppTheme.primary,
                      onPressed: () => _editIngredient(item),
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
