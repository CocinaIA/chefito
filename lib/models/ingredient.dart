class Ingredient {
  final String id; // nombre normalizado en lowercase
  final String name; // nombre legible
  final double quantity; // cantidad numérica
  final String unit; // unidad de medida (unidad, g, kg, ml, l, etc)
  final DateTime createdAt;
  final DateTime updatedAt;
  final String source; // 'manual', 'receipt', etc

  Ingredient({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.createdAt,
    required this.updatedAt,
    this.source = 'manual',
  });

  // Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'source': source,
    };
  }

  // Crear desde Firestore
  factory Ingredient.fromFirestore(Map<String, dynamic> data) {
    return Ingredient(
      id: data['id'] as String? ?? data['name'].toString().toLowerCase(),
      name: data['name'] as String? ?? 'Unknown',
      quantity: (data['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: data['unit'] as String? ?? 'unidad',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
      source: data['source'] as String? ?? 'manual',
    );
  }

  // Display: "500g arroz" o "3 huevos"
  String get display => quantity == quantity.toInt() 
      ? '${quantity.toInt()} $unit $name'
      : '$quantity $unit $name';

  // Para búsqueda: "arroz", "huevo", etc
  String get baseIngredient => name.toLowerCase();

  Ingredient copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? source,
  }) {
    return Ingredient(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }
}
