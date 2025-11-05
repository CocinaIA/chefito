class Recipe {
  final String nombre;
  final String descripcion;
  final List<String> ingredientesUsados;
  final List<String> ingredientesFaltantes;
  final List<String> pasos;
  final String tiempoPreparacion;
  final String dificultad;
  final String? videoSugerido;

  Recipe({
    required this.nombre,
    required this.descripcion,
    required this.ingredientesUsados,
    required this.ingredientesFaltantes,
    required this.pasos,
    required this.tiempoPreparacion,
    required this.dificultad,
    this.videoSugerido,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'] ?? '',
      ingredientesUsados: List<String>.from(json['ingredientes_usados'] ?? []),
      ingredientesFaltantes: List<String>.from(json['ingredientes_faltantes'] ?? []),
      pasos: List<String>.from(json['pasos'] ?? []),
      tiempoPreparacion: json['tiempo_preparacion'] ?? '',
      dificultad: json['dificultad'] ?? '',
      videoSugerido: json['video_sugerido'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'ingredientes_usados': ingredientesUsados,
      'ingredientes_faltantes': ingredientesFaltantes,
      'pasos': pasos,
      'tiempo_preparacion': tiempoPreparacion,
      'dificultad': dificultad,
      'video_sugerido': videoSugerido,
    };
  }
}