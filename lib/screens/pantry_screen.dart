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
    
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => AlertDialog(
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
                decoration: InputDecoration(
                  hintText: 'Ej. 500g, 2kg, 1 unidad',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
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
              'quantity': quantityController.text,
            }),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    
    if (result == null || result['name']!.isEmpty) return;
    
    final normalized = IngredientNormalizer.normalize([result['name']!]);
    if (normalized.isEmpty) return;
    
    // Guardar con cantidad en la descripción
    final fullName = '${normalized.first}${result['quantity']!.isNotEmpty ? ' (${result['quantity']!})' : ''}';
    await _repo.addItem(fullName, source: 'manual');
  }

  Future<void> _editItem(PantryItem item) async {
    final nameController = TextEditingController(text: item.name);
    final quantityController = TextEditingController(text: item.quantity.toString());
    
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar ingrediente'),
        contentPadding: const EdgeInsets.all(20),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nombre del ingrediente',
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
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ej. 1, 2, 3...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
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
              'quantity': quantityController.text,
            }),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    
    if (result == null || result['name']!.isEmpty) return;
    
    final newName = result['name']!.trim();
    final newQuantity = int.tryParse(result['quantity']!) ?? item.quantity;
    
    // Si el nombre cambió, verificar que no exista ya
    if (newName.toLowerCase() != item.name.toLowerCase()) {
      final exists = await _repo.existsItem(newName);
      if (exists && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ya existe un ingrediente llamado "$newName"'),
            backgroundColor: Colors.orange.shade700,
          ),
        );
        return;
      }
    }
    
    // Eliminar el antiguo y agregar el nuevo
    await _repo.removeItem(item.name);
    await _repo.addItem(newName, source: 'edit', quantity: newQuantity);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Actualizado: $newName')),
          ],
        ),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _remove(String name, {int? previousQuantity}) async {
    await _repo.removeItem(name);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Eliminado: $name'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            final qty = (previousQuantity ?? 1).clamp(1, 1000);
            await _repo.addItem(name, source: 'undo', quantity: qty);
          },
        ),
        duration: const Duration(seconds: 3),
      ),
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
      body: StreamBuilder<List<PantryItem>>(
        stream: _repo.streamPantryItems(),
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
              final name = item.name;
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
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: AppTheme.primaryLight.withOpacity(0.3),
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
                    title: Text(
                      name,
                      style: const TextStyle(
                        color: AppTheme.foreground,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Text(
                      'Cantidad: ${item.quantity}',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón editar
                        IconButton(
                          onPressed: () => _editItem(item),
                          icon: Icon(
                            Icons.edit,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                          tooltip: 'Editar nombre',
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 4),
                        // Botón decrementar
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              final deleted = await _repo.adjustQuantity(name, -1);
                              if (deleted && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Eliminado: $name'),
                                    action: SnackBarAction(
                                      label: 'Deshacer',
                                      onPressed: () async {
                                        await _repo.addItem(name, source: 'undo', quantity: 1);
                                      },
                                    ),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.remove, size: 18),
                            color: AppTheme.foreground,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Disminuir cantidad',
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Botón incrementar
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await _repo.adjustQuantity(name, 1);
                            },
                            icon: const Icon(Icons.add, size: 18),
                            color: AppTheme.primary,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            tooltip: 'Aumentar cantidad',
                          ),
                        ),
                      ],
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
