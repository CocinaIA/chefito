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
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
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
