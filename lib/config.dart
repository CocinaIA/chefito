class AppConfig {
  // Configuración para desarrollo local
  static const String appName = 'Chefito';
  static const String appVersion = '1.0.0';
  
  // Proxy para Nanonets (opcional - solo si tienes Worker configurado)
  static const String nanonetsProxyUrl = ''; // Vacío para desactivar
  
  // Base de datos local
  static const String databaseName = 'chefito.db';
  static const int databaseVersion = 1;
  
  // Configuración web
  static const bool isWebOptimized = true;
  static const String landingPageTitle = 'Chefito - Tu Asistente de Cocina Inteligente';
  static const String landingPageDescription = 'Escanea tickets de compra y gestiona tu alacena de forma inteligente';