# Chefito

Chefito te ayuda a extraer ingredientes de un ticket/factura con OCR y guardarlos en tu alacena (Firestore). Con **recetas generadas por IA** con instrucciones detalladas, temperaturas específicas, tiempos de cocción y consejos profesionales.

Este repo incluye:
- Pantalla de escaneo de ticket con ML Kit Text Recognition (on-device OCR)
- Parser y normalizador heurístico para extraer ingredientes
- Alacena (Firestore) con agregar/eliminar y stream en tiempo real
- **Generador de recetas con IA (Google Gemini API):**
  - Recetas detalladas con pasos específicos (mín. 4 pasos)
  - Temperaturas exactas (ej: "180°C hasta que dore")
  - Tiempos de cocción por fase
  - Pistas sensoriales (color, olor, textura, sonido)
  - Consejos profesionales y variaciones
  - Dificultad (fácil/medio/difícil)
- Integración opcional con Nanonets vía:
	- Firebase Functions (callable, con secretos)
	- Proxy HTTP gratuito (Cloudflare Workers) para evitar exponer API keys
- **Consumo automático de stock** al marcar receta como cocinada
- **Edición de cantidad/unidad** después de escanear tickets

## Requisitos
- Flutter 3.x
- Un proyecto de Firebase configurado (ya incluido `firebase_options.dart`)

## Firestore: usar emulador en desarrollo
Por defecto está activado el emulador para evitar errores NOT_FOUND cuando aún no has creado la BD en Firebase.

Archivo: `lib/config.dart`
```
static const bool useFirestoreEmulator = true; // activado por defecto
static const String firestoreEmulatorHost = '10.0.2.2';
static const int firestoreEmulatorPort = 8080;
```

Notas importantes:
- Si usas Android Emulator: `10.0.2.2` está bien.
- Si pruebas en un dispositivo físico: cambia `firestoreEmulatorHost` por la IP local de tu PC (por ejemplo `192.168.1.100`).
- Para producción, desactiva el emulador (pon `false`) y crea tu base de datos Firestore en la consola de Firebase.

## Proxy Nanonets con Cloudflare Workers (recomendado si no quieres usar Functions)
1. Crea un Worker (Wrangler o dashboard) y añade dos secretos:
	 - `NANONETS_API_KEY`
	 - `NANONETS_MODEL_ID`
2. Usa este handler como contenido del Worker (módulos):

```js
export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Use POST' }), { 
        status: 405, 
        headers: { 'Content-Type': 'application/json' } 
      });
    }
    try {
      const { imageUrl, imageBase64 } = await request.json();
      if (!imageUrl && !imageBase64) {
        return new Response(JSON.stringify({ error: 'Provide imageUrl or imageBase64' }), { 
          status: 400, 
          headers: { 'Content-Type': 'application/json' } 
        });
      }

      const apiKey = env.NANONETS_API_KEY;
      const modelId = env.NANONETS_MODEL_ID;
      
      // Usar async=false para respuestas inmediatas sin workflow de revisión
      const endpoint = `https://app.nanonets.com/api/v2/OCR/Model/${modelId}/LabelFile/?async=false`;

      const form = new FormData();
      if (imageUrl) {
        form.append('urls', imageUrl);
      }
      if (imageBase64) {
        const bytes = Uint8Array.from(atob(imageBase64), c => c.charCodeAt(0));
        form.append('file', new Blob([bytes], { type: 'image/jpeg' }), 'receipt.jpg');
      }

      const resp = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'Authorization': 'Basic ' + btoa(apiKey + ':'),
        },
        body: form,
      });

      if (!resp.ok) {
        const text = await resp.text();
        return new Response(JSON.stringify({ 
          error: 'Nanonets failed', 
          status: resp.status, 
          body: text 
        }), { 
          status: 502, 
          headers: { 'Content-Type': 'application/json' } 
        });
      }

      const data = await resp.json();
      
      // Extraer SOLO los nombres de productos (Description) con cantidades opcionales
      const ingredients = [];
      const results = data?.result || [];
      
      for (const r of results) {
        const preds = r?.prediction || [];
        
        // Buscar líneas de productos en la tabla
        const tableData = {};
        for (const p of preds) {
          const label = p?.label?.toLowerCase();
          const text = (p?.ocr_text || p?.text || '').trim();
          
          if (!text || text.length < 2) continue;
          
          // Agrupar por label para cada fila
          const rowIndex = p?.row_index ?? p?.cells?.[0]?.row ?? 0;
          if (!tableData[rowIndex]) tableData[rowIndex] = {};
          
          // Guardar valores según el campo
          if (label === 'description' || label === 'product_code') {
            tableData[rowIndex].description = text;
          } else if (label === 'quantity') {
            tableData[rowIndex].quantity = text;
          }
          // IGNORAR: price, line_amount, subtax, total, merchant_*, etc.
        }
        
        // Construir lista de ingredientes desde las filas de tabla
        for (const rowIndex in tableData) {
          const row = tableData[rowIndex];
          if (row.description) {
            // Formato: "Descripción" o "Descripción (cantidad)" si hay cantidad
            const ingredient = row.quantity 
              ? `${row.description} (${row.quantity})`
              : row.description;
            ingredients.push(ingredient);
          }
        }
      }

      return new Response(JSON.stringify({ 
        ingredients: ingredients, 
        raw: data,
        count: ingredients.length
      }), {
        headers: { 'Content-Type': 'application/json' },
      });
      
    } catch (e) {
      return new Response(JSON.stringify({ 
        error: e?.message || String(e),
        stack: e?.stack
      }), { 
        status: 500, 
        headers: { 'Content-Type': 'application/json' } 
      });
    }
  }
}
```

3. Copia la URL del Worker y ponla en `lib/config.dart`:
```
static const String nanonetsProxyUrl = 'https://<tu-worker>.workers.dev';
```

En la app, en la pantalla de ticket, pulsa “Usar Nanonets (Proxy)”.

## Firebase Functions (alternativa)
Si prefieres una función callable, hay soporte en `lib/services/receipt_ai_service.dart` para llamar `nanonetsParseReceipt` (asegúrate de haber desplegado la función con secretos).

## Parser/Normalizador
- `lib/services/receipt_parser.dart`: heurísticas para filtrar precios/códigos y palabras administrativas y quedarse con descripciones de productos.
- `lib/services/ingredient_normalizer.dart`: minúsculas, sinónimos, singularización simple, eliminación de determinantes y descriptores.

## Pantallas
- `lib/screens/receipt_scanner_screen.dart`: OCR con ML Kit, integra Nanonets (Function/Proxy), guarda ingredientes detectados en Firestore.
- `lib/screens/pantry_screen.dart`: lista la alacena, permite agregar y eliminar.
- `lib/screens/recipes_screen.dart`: recetas del catálogo + **recetas generadas con IA (detalladas)**.

## 🍳 Recetas Generadas con IA (Detalladas)

La app genera recetas profesionales usando **Google Gemini API** con instrucciones paso a paso, temperaturas exactas, tiempos de cocción, consejos y variaciones.

**Características:**
- ✅ Mínimo 4 pasos detallados por receta
- 🌡️ Temperaturas exactas (ej: "180°C")
- ⏱️ Tiempos específicos para cada fase
- 👁️ Pistas sensoriales (color, olor, textura, sonido)
- 📏 Tamaños de corte precisos ("picado fino", "rebanadas de 2cm", etc)
- 👨‍🍳 Terminología profesional de cocina
- 💡 Consejos profesionales y errores comunes
- 🔄 Variaciones de ingredientes y métodos
- 📊 Dificultad (fácil/medio/difícil)
- 🍽️ Número de porciones
- ⏲️ Tiempo total de preparación

**Ejemplo de Receta Generada:**
```
Arroz Frito con Huevos
"Delicious Asian-inspired fried rice with fresh vegetables"

Porciones: 4 | Tiempo: 20 min | Dificultad: Medio 👨‍🍳

Pasos:
1. (PREPARACIÓN): Pica las verduras en cubos uniformes de 5mm. Bate 3 huevos con 1 tbsp de salsa soya.

2. (COCCIÓN): Calienta aceite a 180°C (shimmer visible). Agrega ajo, cocina 30 seg hasta oler fragante.

3. (ARROZ): Añade arroz precocido, separa los granos. Fríe 3 minutos hasta que empiece a disminuir el sonido de fritado.

4. (ACABADO): Vierte huevos batidos, mezcla rápido 1 minuto. Agrega salsa soya (2 tbsp) y aceite de sésamo (1 tbsp).

Consejos Profesionales:
✨ Usa arroz de un día anterior (el fresco queda musgo)
✨ Mantén calor alto para evitar que se vaporice el arroz

Variaciones:
👉 Sustituye con camarones o pollo para más proteína
👉 Añade anacardos o cacahuates para textura crujiente
```

**Tecnología:**
- Google Gemini 2.5 Flash (modelo rápido y eficiente)
- Worker de Cloudflare (proxy para llamadas a API)
- Almacenamiento local de recetas (para offline)
- Consumo automático de stock al marcar como cocinada

Ver documentación completa: [`DETAILED_RECIPES_IMPLEMENTATION.md`](./DETAILED_RECIPES_IMPLEMENTATION.md)

## Tests
Test de humo: `test/widget_test.dart` comprueba que la Home renderiza botones principales.

## Problemas comunes
- Firestore NOT_FOUND: activa el emulador (ya viene activo) o crea la BD en Firebase Console.
- Dispositivo físico con emulador: cambia `firestoreEmulatorHost` a la IP local de tu PC.
- Proxy devuelve “Hello World!”: tu Worker está con el template; reemplázalo por el handler JSON anterior y vuelve a desplegar.

