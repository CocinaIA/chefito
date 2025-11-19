# 🍳 Chefito - Setup para Desarrolladores

Esta guía explica cómo configurar el proyecto localmente y obtener todas las APIs necesarias.

## 📋 Requisitos

- **Flutter 3.9.2+** - [Descargar](https://flutter.dev/docs/get-started/install)
- **Git** - Para clonar el repo
- **Chrome** (opcional) - Para correr en web
- **Cuenta en Google Cloud** - Para Gemini API
- **Cuenta en Nanonets** - Para OCR de recibos
- **Firebase Project** - Para la base de datos

---

## 🚀 Instalación Inicial

### 1. Clonar el repositorio

```bash
git clone https://github.com/CocinaIA/chefito.git
cd chefito
git checkout Maldo  # Rama con todas las features
```

### 2. Instalar dependencias Flutter

```bash
flutter pub get
```

### 3. Generar archivos de Firebase

```bash
# Necesitas flutterfire_cli
dart pub global activate flutterfire_cli

# Configurar Firebase para tu proyecto
flutterfire configure
```

---

## 🔑 APIs y Credenciales

### A. Firebase Setup (Base de datos + Auth)

1. **Ve a [Firebase Console](https://console.firebase.google.com)**
2. Crea un nuevo proyecto o usa uno existente: **"chefito"**
3. Habilita estos servicios:
   - ✅ Firestore Database (Produción)
   - ✅ Authentication (Anónima)
   - ✅ Cloud Functions (si usas Cloud Functions)

4. **Descarga las credenciales:**
   - Android: `google-services.json` → `android/app/`
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`
   - Web: Se genera automáticamente con `flutterfire configure`

5. **Asegúrate que las reglas de Firestore permitan lectura/escritura anónima:**

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

### B. Google Gemini API (Generación de Recetas)

1. **Ve a [Google AI Studio](https://aistudio.google.com/app/apikeys)**
2. Crea una API Key gratuita
3. **Guarda esta clave en tu Cloudflare Worker** (ver sección C)

---

### C. Cloudflare Worker Setup (Proxy para APIs)

Este proyecto usa un **Cloudflare Worker** como proxy seguro para las APIs.

**Ubicación:** `/chefito-nanonets-worker`

#### Configuración:

1. **Crea cuenta en [Cloudflare](https://dash.cloudflare.com)**

2. **Deploy del Worker:**
   ```bash
   cd chefito-nanonets-worker
   npm install
   npm run deploy
   ```

3. **Configura los secrets (variables de entorno):**
   ```bash
   npx wrangler secret put GOOGLE_API_KEY
   # Pega tu Google Gemini API Key
   
   npx wrangler secret put NANONETS_API_KEY
   # Pega tu Nanonets API Key
   
   npx wrangler secret put NANONETS_MODEL_ID
   # Pega tu Nanonets Model ID
   ```

4. **Anota la URL del worker deployado:**
   - Formato: `https://chefito-nanonets-worker.<tu-id>.workers.dev`
   - Actualiza en `lib/config.dart` si es diferente

---

### D. Nanonets API (OCR de Recibos) - OPCIONAL

Si quieres usar reconocimiento de recibos:

1. **Ve a [Nanonets](https://nanonets.com/)**
2. Regístrate (plan gratuito disponible)
3. Crea un modelo OCR para recibos
4. Obtén:
   - **NANONETS_API_KEY** - Tu API key
   - **NANONETS_MODEL_ID** - ID de tu modelo
5. **Configúralos en el Cloudflare Worker** (paso C.3)

---

## 📦 Estructura del Proyecto

```
chefito/
├── lib/
│   ├── main.dart              # App principal
│   ├── config.dart            # URLs de APIs
│   ├── theme.dart             # Tema personalizado
│   ├── screens/               # Pantallas de la app
│   ├── services/              # Lógica de negocio
│   └── firebase_options.dart  # Credenciales Firebase (auto-generado)
├── chefito-nanonets-worker/   # Cloudflare Worker
│   ├── src/index.js           # Código del worker
│   └── wrangler.jsonc         # Configuración Wrangler
├── pubspec.yaml               # Dependencias Flutter
├── vercel.json                # Configuración para Vercel
└── firebase.json              # Configuración Firebase
```

---

## 🏃 Correr la App

### En Chrome (Web)
```bash
flutter run -d chrome
```

### En Android
```bash
flutter run -d android
```

### En iOS (macOS/Linux no soportado para iOS)
```bash
flutter run -d ios
```

---

## 🚀 Deploy en Producción

### Opción 1: Vercel (Recomendado para Web)

```bash
# El proyecto ya está configurado
git push origin Maldo
# Vercel deployará automáticamente desde vercel.json
```

**URL deployada:** Se mostrará en Vercel después del deploy

### Opción 2: Firebase Hosting

```bash
# Compilar web
flutter build web

# Deploy
firebase deploy --only hosting
```

---

## ✅ Checklist de Setup

- [ ] Flutter 3.9.2+ instalado
- [ ] Repo clonado en rama `Maldo`
- [ ] `flutter pub get` ejecutado
- [ ] Firebase proyecto creado
- [ ] `flutterfire configure` completado
- [ ] Credenciales Firebase descargadas
- [ ] Google Gemini API Key generada
- [ ] Cloudflare Worker deployado
- [ ] Secrets configurados en Worker
- [ ] Nanonets setup (opcional)
- [ ] URLs actualizadas en `lib/config.dart`
- [ ] `flutter run -d chrome` funciona

---

## 🐛 Troubleshooting

### "Firebase not initialized"
```bash
flutterfire configure
flutter pub get
flutter clean
flutter pub get
```

### "Connection refused" al conectar APIs
- Verifica que `lib/config.dart` tenga las URLs correctas
- Verifica que el Cloudflare Worker esté deployado: `npm run deploy`

### "Gemini API error"
- Verifica la Google API Key en Cloudflare: `npx wrangler secret list`
- Asegúrate que está dentro de los límites de cuota gratis

### "Nanonets not working"
- Verifica que NANONETS_API_KEY y NANONETS_MODEL_ID estén configurados
- Prueba la API directamente en el dashboard de Nanonets

---

## 💡 Tips de Desarrollo

- **Hot reload:** Presiona `r` en la terminal mientras `flutter run` está activo
- **Debug prints:** Usa `debugPrint('message')` - aparecen en la consola
- **Firestore emulator:** Desactualizado en producción (`lib/config.dart`)
- **Worker logs:** `npx wrangler tail` en la terminal

---

## 📚 Recursos Útiles

- [Flutter Docs](https://flutter.dev/docs)
- [Firebase Docs](https://firebase.google.com/docs)
- [Google Gemini API](https://ai.google.dev/)
- [Cloudflare Workers](https://workers.cloudflare.com/)
- [Nanonets OCR](https://nanonets.com/documentation)

---

## ❓ ¿Problemas?

1. Revisa el [README.md](./README.md)
2. Verifica todos los secrets de Cloudflare
3. Abre un issue en GitHub
4. Contacta al equipo

¡Bienvenido al desarrollo de Chefito! 🎉
