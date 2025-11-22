import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/ingredient.dart';

class PantryRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  PantryRepository({FirebaseFirestore? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? 'anon';

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('users').doc(_uid).collection('pantry');

  Future<void> addItems(List<String> names, {String source = 'receipt'}) async {
    debugPrint('🔥 PantryRepository.addItems called with ${names.length} items');
    debugPrint('🔥 User ID: $_uid');
    
    final batch = _db.batch();
    final now = DateTime.now();
    for (final name in names) {
      final id = name.toLowerCase();
      final doc = _collection.doc(id);
      final ingredient = Ingredient(
        id: id,
        name: name,
        quantity: 1.0,
        unit: 'unidad',
        createdAt: now,
        updatedAt: now,
        source: source,
      );
      debugPrint('🔥 Adding ingredient: ${ingredient.display}');
      batch.set(doc, ingredient.toFirestore(), SetOptions(merge: true));
    }
    
    debugPrint('🔥 Committing batch...');
    try {
      await batch.commit();
      debugPrint('✅ Batch committed successfully!');
    } catch (e, stack) {
      debugPrint('❌ Error committing batch: $e');
      debugPrint('Stack trace: $stack');
      rethrow;
    }
  }

  Future<void> addItem(String name, {String source = 'manual', double quantity = 1.0, String unit = 'unidad'}) async {
    final now = DateTime.now();
    final id = name.toLowerCase();
    final ingredient = Ingredient(
      id: id,
      name: name,
      quantity: quantity,
      unit: unit,
      createdAt: now,
      updatedAt: now,
      source: source,
    );
    await _collection.doc(id).set(ingredient.toFirestore(), SetOptions(merge: true));
  }

  // Actualizar cantidad de un ingrediente (para consumo)
  Future<void> updateIngredientQuantity(String ingredientId, double newQuantity) async {
    final id = ingredientId.toLowerCase();
    await _collection.doc(id).update({
      'quantity': newQuantity,
      'updatedAt': DateTime.now(),
    });
  }

  // Consumir cantidad de un ingrediente (resta)
  Future<void> consumeIngredient(String ingredientId, double amountToConsume) async {
    final id = ingredientId.toLowerCase();
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return;
    
    final current = Ingredient.fromFirestore(doc.data() as Map<String, dynamic>);
    final newQuantity = (current.quantity - amountToConsume).clamp(0.0, double.infinity);
    
    // Si la cantidad llega a 0 o menos, eliminar el ingrediente
    if (newQuantity <= 0) {
      await _collection.doc(id).delete();
      debugPrint('🗑️ Ingrediente ${current.name} eliminado (cantidad llegó a 0)');
    } else {
      await _collection.doc(id).update({
        'quantity': newQuantity,
        'updatedAt': DateTime.now(),
      });
      debugPrint('🔥 Consumed $amountToConsume from ${current.name}: ${current.quantity} -> $newQuantity');
    }
  }

  Future<void> removeItem(String name) async {
    final id = name.toLowerCase();
    await _collection.doc(id).delete();
  }

  Stream<List<String>> streamPantry() {
    return _collection.snapshots().map((snap) =>
        snap.docs.map((d) {
          final ing = Ingredient.fromFirestore(d.data());
          return ing.display; // Mostrar "3 huevos", "500g arroz", etc
        }).toList());
  }

  Stream<List<Ingredient>> streamPantryIngredients() {
    return _collection.snapshots().map((snap) =>
        snap.docs.map((d) => Ingredient.fromFirestore(d.data())).toList());
  }

  Future<List<String>> getAllItems() async {
    final snap = await _collection.get();
    return snap.docs.map((d) {
      final ing = Ingredient.fromFirestore(d.data());
      return ing.display;
    }).toList();
  }

  Future<List<Ingredient>> getAllIngredients() async {
    final snap = await _collection.get();
    return snap.docs.map((d) => Ingredient.fromFirestore(d.data())).toList();
  }

  Future<Ingredient?> getIngredient(String ingredientId) async {
    final id = ingredientId.toLowerCase();
    final doc = await _collection.doc(id).get();
    if (!doc.exists) return null;
    return Ingredient.fromFirestore(doc.data() as Map<String, dynamic>);
  }
}
