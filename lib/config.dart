class AppConfig {
  // Set this to your Cloudflare Worker or other proxy endpoint if you prefer not to use Firebase Functions.
  // Example: 'https://chefito-nanonets-worker.your-id.workers.dev'
  // Leave empty unless you've configured the Nanonets proxy route and secrets on your Worker
  static const String nanonetsProxyUrl = '';

  // AI recipes generation endpoint (Cloudflare Worker)
  static const String recipesAiUrl = 'https://chefito-nanonets-worker.chefito-ai.workers.dev/recipes/generate';

  // Use Firestore emulator instead of production (set true for desarrollo sin crear BD en Firebase).
  static const bool useFirestoreEmulator = false; // DESACTIVADO temporalmente - usar producción
  // Host y puerto del emulador. Para Android Emulator usa 10.0.2.2; para dispositivo físico usa la IP de tu PC.
  // IMPORTANTE: Si usas DISPOSITIVO FÍSICO, cambia a '192.168.1.22' (tu IP local de PC)
  static const String firestoreEmulatorHost = '192.168.1.22'; // O '192.168.1.22' para dispositivo físico
  static const int firestoreEmulatorPort = 8080;
}
