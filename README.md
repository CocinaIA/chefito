# Chefito - Asistente de Cocina Inteligente 🧑‍🍳

Chefito es una aplicación Flutter que te ayuda a gestionar tu cocina de forma inteligente. Escanea tickets de compra, reconoce ingredientes automáticamente y organiza tu alacena usando tecnologías de OCR e Inteligencia Artificial.

## ✨ Características principales

- **Escaneo de tickets**: Usa OCR local (ML Kit) para extraer ingredientes de facturas
- **Reconocimiento de ingredientes**: Identifica ingredientes individuales mediante IA
- **Alacena inteligente**: Gestiona tu inventario de ingredientes de forma organizada
- **Base de datos local**: Todos tus datos se almacenan localmente usando SQLite
- **Funciona offline**: No requiere conexión a internet para las funciones básicas
- **Landing page web**: Interfaz optimizada para navegadores web

## 🚀 Tecnologías utilizadas

- **Flutter**: Framework multiplataforma
- **SQLite**: Base de datos local para almacenamiento persistente
- **ML Kit**: OCR y reconocimiento de imágenes de Google
- **Dart**: Lenguaje de programación
- **Material Design 3**: Diseño moderno y responsive

## 📱 Plataformas soportadas

- ✅ **Web** (Optimizado como landing page)
- ✅ **Android** 
- ✅ **iOS**
- ✅ **Windows**
- ✅ **macOS**
- ✅ **Linux**

## 🛠️ Instalación y configuración

### Prerrequisitos

- Flutter SDK 3.9.2 o superior
- Dart SDK
- Android Studio / Xcode (para desarrollo móvil)
- Un editor como VS Code

### Configuración del proyecto

1. **Clona el repositorio**
```bash
git clone <tu-repo>
cd chefito
```

2. **Instala las dependencias**
```bash
flutter pub get
```

3. **Ejecuta la aplicación**

Para web (landing page):
```bash
flutter run -d chrome
```

Para móvil:
```bash
flutter run
```

Para escritorio:
```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

## 🏗️ Estructura del proyecto

```
lib/
├── config.dart                 # Configuración global
├── models/
│   └── ingredient.dart          # Modelo de datos de ingredientes
├── services/
│   ├── database_helper.dart     # Helper para SQLite
│   ├── pantry_repository.dart   # Repositorio de la alacena
│   ├── receipt_parser.dart      # Parser de tickets
│   ├── ingredient_normalizer.dart # Normalizador de ingredientes
│   └── receipt_ai_service.dart  # Servicio de IA (opcional)
├── screens/
│   ├── pantry_screen.dart       # Pantalla de la alacena
│   ├── receipt_scanner_screen.dart # Escáner de tickets
│   └── web_landing_screen.dart  # Landing page web
└── main.dart                    # Punto de entrada
```

## 🎯 Funcionalidades principales

### 1. Escaneo de tickets
- Toma fotos de tickets de compra
- Extrae automáticamente los ingredientes usando OCR
- Filtra ruido administrativo (precios, totales, etc.)
- Normaliza nombres de ingredientes

### 2. Reconocimiento individual
- Identifica ingredientes individuales mediante foto
- Usa ML Kit Image Labeling
- Permite confirmación antes de agregar a la alacena

### 3. Gestión de alacena
- Lista todos tus ingredientes organizadamente
- Búsqueda en tiempo real
- Eliminar elementos por deslizar
- Limpieza automática de duplicados y ruido
- Persistencia local con SQLite

### 4. Landing page web
- Interfaz optimizada para navegadores
- Estadísticas de uso
- Llamadas a la acción claras
- Responsive design

## 🔧 Configuración avanzada

### OCR con Nanonets (Opcional)
Si quieres mejorar la precisión del OCR, puedes configurar un proxy con Nanonets:

1. Configura un Cloudflare Worker con tu API key de Nanonets
2. Actualiza `lib/config.dart`:
```dart
static const String nanonetsProxyUrl = 'https://tu-worker.workers.dev';
```

### Personalización de base de datos
Modifica `lib/config.dart` para ajustar la configuración:
```dart
static const String databaseName = 'mi_chefito.db';
static const int databaseVersion = 1;
```

## 🚀 Despliegue

### Web (GitHub Pages / Netlify / Vercel)
```bash
flutter build web --release
# Sube la carpeta build/web/ a tu hosting
```

### Android
```bash
flutter build apk --release
# O para app bundle:
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
# Luego usa Xcode para distribuir
```

### Escritorio
```bash
flutter build windows --release
flutter build macos --release  
flutter build linux --release
```

## 🎨 Personalización

### Colores y tema
Modifica `lib/main.dart` para cambiar la apariencia:
```dart
theme: ThemeData(
  primarySwatch: Colors.green,  // Cambia el color principal
  useMaterial3: true,
),
```

### Textos y configuración
Actualiza `lib/config.dart` para personalizar textos:
```dart
static const String appName = 'Tu Nombre de App';
static const String landingPageTitle = 'Tu título personalizado';
```

## 🐛 Solución de problemas

### Error de permisos en Android
Asegúrate de que `android/app/src/main/AndroidManifest.xml` tenga:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
```

### Base de datos no se crea
Verifica que SQLite esté funcionando:
```bash
flutter clean
flutter pub get
flutter run
```

### Problemas con ML Kit
En Android, asegúrate de que tu `android/app/build.gradle` tenga:
```gradle
minSdkVersion flutter.minSdkVersion  // Mínimo 21
compileSdk 34
```

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agrega nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 🙏 Agradecimientos

- **Google ML Kit** por las tecnologías de OCR e IA
- **Flutter Team** por el excelente framework
- **SQLite** por la base de datos confiable y liviana
- **Comunidad Flutter** por su apoyo y recursos

## 📞 Soporte

Si tienes preguntas o problemas:

1. Revisa la documentación de Flutter: https://flutter.dev/docs
2. Consulta los issues de este repositorio
3. Abre un nuevo issue describiendo tu problema

---

¡Hecho con ❤️ y mucha comida! 🍳