import 'package:flutter/material.dart';

import '../services/pantry_repository.dart';
import '../services/ingredient_normalizer.dart';
import '../services/receipt_parser.dart';

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
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar ingrediente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. tomate, cebolla, arroz',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad',
                hintText: '1',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': nameCtrl.text,
              'quantity': qtyCtrl.text,
            }),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final rawName = (result['name'] as String? ?? '').trim();
    final qtyStr = (result['quantity'] as String? ?? '1').trim();
    final quantity = int.tryParse(qtyStr) ?? 1;
    final normalized = IngredientNormalizer.normalize([rawName]);
    if (normalized.isEmpty) return;
    final name = normalized.first;
    if (await _repo.existsItem(name)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" ya existe. Usa los botones +/- para ajustar la cantidad.')),
      );
      return;
    }
    await _repo.addItem(name, source: 'manual', quantity: quantity.clamp(1, 1000));
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
        title: const Text('Mi alacena'),
        actions: [
          IconButton(
            tooltip: 'Limpiar ruido',
            onPressed: _cleanPantry,
            icon: const Icon(Icons.cleaning_services_outlined),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addManually,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<PantryItem>>(
        stream: _repo.streamPantryItems(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.kitchen, size: 48, color: Colors.black26),
                  SizedBox(height: 8),
                  Text('Tu alacena está vacía'),
                  SizedBox(height: 4),
                  Text('Agrega ingredientes manualmente o escanea un ticket'),
                ],
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
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
                onDismissed: (_) => _remove(name, previousQuantity: item.quantity),
                child: ListTile(
                  title: Text(name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Disminuir',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () async {
                          final deleted = await _repo.adjustQuantity(name, -1);
                          if (deleted && mounted) {
                            final messenger = ScaffoldMessenger.of(context);
                            messenger.showSnackBar(
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
                      ),
                      Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.w600)),
                      IconButton(
                        tooltip: 'Aumentar',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () async {
                          await _repo.adjustQuantity(name, 1);
                        },
                      ),
                    ],
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
