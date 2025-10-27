import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

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
    debugPrint('🔥 Collection path: users/$_uid/pantry');
    debugPrint('🔥 Firestore settings: ${_db.settings}');
    
    final batch = _db.batch();
    final now = DateTime.now();
    for (final name in names) {
      final id = name.toLowerCase();
      final doc = _collection.doc(id);
  debugPrint('🔥 Adding document: $id with name: $name');
      batch.set(doc, {
        'name': name,
        'source': source,
        'updatedAt': now,
        'createdAt': now,
      }, SetOptions(merge: true));
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

  Future<void> addItem(String name, {String source = 'manual'}) async {
    final now = DateTime.now();
    final id = name.toLowerCase();
    await _collection.doc(id).set({
      'name': name,
      'source': source,
      'updatedAt': now,
      'createdAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> removeItem(String name) async {
    final id = name.toLowerCase();
    await _collection.doc(id).delete();
  }

  Stream<List<String>> streamPantry() {
    return _collection.snapshots().map((snap) =>
        snap.docs.map((d) => (d.data()['name'] as String?) ?? d.id).toList());
  }

  Future<List<String>> getAllItems() async {
    final snap = await _collection.get();
    return snap.docs.map((d) => (d.data()['name'] as String?) ?? d.id).toList();
  }
}
