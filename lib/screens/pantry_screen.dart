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
  final _searchController = TextEditingController();
  List<String> _filteredItems = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _repo.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _cleanPantry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar alacena'),
        content: const Text('¿Estás seguro de que quieres eliminar elementos duplicados y ruido administrativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final all = await _repo.getAllItems();
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
    final controller = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar ingrediente'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej. tomate, cebolla, arroz',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    
    if (name == null || name.trim().isEmpty) return;
    
    final normalized = IngredientNormalizer.normalize([name]);
    if (normalized.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El ingrediente no es válido')),
        );
      }
      return;
    }
    
    await _repo.addItem(normalized.first, source: 'manual');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ingrediente agregado: ${normalized.first}')),
      );
    }
  }

  Future<void> _remove(String name) async {
    await _repo.removeItem(name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Eliminado: $name'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _repo.addItem(name, source: 'manual'),
        ),
      ),
    );
  }

  List<String> _filterItems(List<String> items) {
    if (_searchQuery.isEmpty) return items;
    return items.where((item) => 
      item.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi alacena'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Limpiar ruido',
            onPressed: _cleanPantry,
            icon: const Icon(Icons.cleaning_services_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'clear_all':
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Vaciar alacena'),
                      content: const Text('¿Estás seguro de que quieres eliminar todos los ingredientes?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Eliminar todo'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _repo.clearPantry();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Alacena vaciada')),
                      );
                    }
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_forever),
                  title: Text('Vaciar alacena'),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addManually,
        tooltip: 'Agregar ingrediente',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar ingredientes...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // Lista de ingredientes
          Expanded(
            child: StreamBuilder<List<String>>(
              stream: _repo.streamPantry(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allItems = snapshot.data ?? [];
                final items = _filterItems(allItems);
                
                if (allItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.kitchen,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tu alacena está vacía',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agrega ingredientes manualmente o escanea un ticket',
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (items.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron ingredientes',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Intenta con otro término de búsqueda',
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Contador de resultados
                    if (_searchQuery.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.grey[100],
                        child: Text(
                          'Mostrando ${items.length} de ${allItems.length} ingredientes',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    // Lista
                    Expanded(
                      child: ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final name = items[index];
                          return Dismissible(
                            key: ValueKey('${name}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.redAccent,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            onDismissed: (_) => _remove(name),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                child: Text(
                                  name[0].toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(fontSize: 16),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _remove(name),
                                tooltip: 'Eliminar',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}