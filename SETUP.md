# 🍳 Chefito - Setup para Desarrolladores

Esta guía explica cómo configurar el proyecto localmente y obtener todas las APIs necesarias.

## 📋 Requisitos

- **Flutter 3.9.2+** - [Descargar](https://flutter.dev/docs/get-started/install)
- **Git** - Para clonar el repo
- **Chrome** (opcional) - Para correr en web

### Nota: APIs Ya Configuradas ✅

Las credenciales públicas ya están embebidas, así que **NO necesitas:**
- ❌ Cuenta en Google Cloud (Gemini API ya está)
- ❌ Cuenta en Nanonets (OCR está deshabilitado por defecto)
- ❌ Generar secretos en Cloudflare (Worker ya está deployado)

Si quieres usar tus propias credenciales, eso es opcional (ver sección "APIs y Credenciales").

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

### ✅ Buenas Noticias: Las APIs están embebidas

Las credenciales públicas ya están en el código:

- **Google Gemini API** ✅ Embebida en `chefito-nanonets-worker/src/index.js`
- **Firebase** ✅ Embebida en `lib/firebase_options.dart`

**No necesitas configurar secretos manualmente.** Solo clona, haz `flutter pub get` y ¡corre!

### A. Firebase (Ya configurado)

El proyecto ya usa estas credenciales de Firebase embebidas:

```dart
// lib/firebase_options.dart
apiKey: 'AIzaSyD0nhZQIrb6eMmLrDd63YXUEc2hIqJ8VIU'
projectId: 'chefito-74733'
authDomain: 'chefito-74733.firebaseapp.com'
```

**Si quieres usar tu propio Firebase:**

1. Ve a [Firebase Console](https://console.firebase.google.com)
2. Crea un proyecto nuevo
3. Corre `flutterfire configure` para generar `lib/firebase_options.dart`
4. Configura las reglas de Firestore:

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

### B. Google Gemini API (Ya configurada)

La API Key está embebida:

```javascript
// chefito-nanonets-worker/src/index.js
const apiKey = 'AIzaSyBr12dPL50ec23cdDv0My9I_L4ZcpiP6Qo';
```

**Si quieres usar tu propia API Key:**

1. Ve a [Google AI Studio](https://aistudio.google.com/app/apikeys)
2. Crea una API Key nueva (gratuita)
3. Reemplaza la clave en `chefito-nanonets-worker/src/index.js` (línea ~82 y ~304)

### C. Cloudflare Worker (Ya Deployado ✅)

El Worker ya está deployado y funcionando:

**URL del Worker:** `https://chefito-nanonets-worker.chefito-ai.workers.dev`

Las credenciales ya están embebidas en el código, así que no necesitas configurar secretos.

**Si quieres deployar tu propio Worker:**

1. Crea cuenta en [Cloudflare](https://dash.cloudflare.com)
2. Instala Wrangler:
   ```bash
   npm install -g wrangler
   ```
3. Deploy:
   ```bash
   cd chefito-nanonets-worker
   npm install
   npm run deploy
   ```
4. Actualiza la URL en `lib/config.dart` si es diferente

---

### D. Nanonets API (OCR de Recibos) - OPCIONAL

Reconocimiento de recibos está DESHABILITADO por defecto (usa Gemini en su lugar).

Si quieres habilitar OCR real de recibos:

1. Ve a [Nanonets](https://nanonets.com/)
2. Regístrate (plan gratuito disponible)
3. Crea un modelo OCR para recibos
4. Obtén:
   - **NANONETS_API_KEY** - Tu API key
   - **NANONETS_MODEL_ID** - ID de tu modelo
5. Reemplaza en `chefito-nanonets-worker/src/index.js` (línea ~327)

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

## ✅ Checklist de Setup (Mínimo)

- [ ] Flutter 3.9.2+ instalado
- [ ] Repo clonado en rama `Maldo`
- [ ] `flutter pub get` ejecutado
- [ ] `flutter run -d chrome` funciona ✅

¡Eso es todo! Las APIs ya están listas para usar.

### Checklist Opcional (Si quieres cambiar credenciales)

- [ ] Firebase proyecto propio creado
- [ ] `flutterfire configure` completado
- [ ] Google Gemini API Key generada
- [ ] Cloudflare Worker deployado
- [ ] Secrets configurados en Worker
- [ ] URLs actualizadas en `lib/config.dart`

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
