import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/ingredient.dart';
import '../config.dart';

class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._internal();
  
  static DatabaseHelper get instance {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, AppConfig.databaseName);

    return await openDatabase(
      path,
      version: AppConfig.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        source TEXT NOT NULL DEFAULT 'manual',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_ingredients_name ON ingredients(name)
    ''');

    await db.execute('''
      CREATE INDEX idx_ingredients_source ON ingredients(source)
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Implementar migraciones futuras aquí
  }

  // CRUD Operations
  Future<int> insertIngredient(Ingredient ingredient) async {
    final db = await database;
    return await db.insert(
      'ingredients',
      ingredient.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Ingredient>> getAllIngredients() async {
    final db = await database;
    final maps = await db.query(
      'ingredients',
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => Ingredient.fromMap(map)).toList();
  }

  Future<Ingredient?> getIngredientByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'ingredients',
      where: 'name = ?',
      whereArgs: [name.toLowerCase()],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Ingredient.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Ingredient>> searchIngredients(String query) async {
    final db = await database;
    final maps = await db.query(
      'ingredients',
      where: 'name LIKE ?',
      whereArgs: ['%${query.toLowerCase()}%'],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Ingredient.fromMap(map)).toList();
  }

  Future<int> updateIngredient(Ingredient ingredient) async {
    final db = await database;
    return await db.update(
      'ingredients',
      ingredient.toMap(),
      where: 'id = ?',
      whereArgs: [ingredient.id],
    );
  }

  Future<int> deleteIngredient(int id) async {
    final db = await database;
    return await db.delete(
      'ingredients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteIngredientByName(String name) async {
    final db = await database;
    return await db.delete(
      'ingredients',
      where: 'name = ?',
      whereArgs: [name.toLowerCase()],
    );
  }

  Future<void> clearAllIngredients() async {
    final db = await database;
    await db.delete('ingredients');
  }

  Future<int> getIngredientsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM ingredients');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}