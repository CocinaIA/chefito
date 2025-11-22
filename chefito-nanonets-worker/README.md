# Chefito Cloudflare Worker

Este Worker expone:

- `GET /health` → estado simple
- `POST /recipes/generate` → genera recetas con Gemini (modelo flash) a partir de `ingredients: string[]`
- `POST /nanonets/parse` → proxy a Nanonets OCR. Acepta `{ imageUrl?: string, imageBase64?: string }` y devuelve `{ ingredients: string[], raw, count }`.

Respuesta JSON esperada:

```json
{
  "recipes": [
    {
      "title": "string",
      "used": ["string"],
      "missing": ["string"],
      "steps": ["string"]
    }
  ]
}
```

## Requisitos

- Node.js >= 20.18.1 (o 22.x LTS)
- `wrangler` (se usa vía `npx`)
- Un Cloudflare API Token con scopes mínimos:
  - Account → Scripts de Workers: Edit
  - Account → Secrets Store: Write
  - (Opcional) Zone → Workers Routes: Edit (solo si se mapeará a un dominio)

## Variables de entorno (PowerShell en Windows)

```powershell
Set-Location -Path 'C:\ANDES\chefito\chefito-nanonets-worker'
$env:CLOUDFLARE_API_TOKEN = 'TU_TOKEN_CLOUDFLARE'
$env:CLOUDFLARE_ACCOUNT_ID = 'TU_ACCOUNT_ID'
```

## Registrar subdominio workers.dev (solo la primera vez)

Wrangler preguntará:

```
Would you like to register a workers.dev subdomain now? yes
What would you like your workers.dev subdomain to be?
```

Sugerencias: `chefito`, `chefito-ai`, `cocinaia-chefito`. Debe ser único globalmente.

## Secretos

Guarda la API Key de Gemini como secreto sin exponerla en código:

```powershell
npx wrangler secret put GOOGLE_API_KEY
# Pega aquí la API Key de Gemini cuando lo pida
```

Para Nanonets (opcional, solo si usarás el proxy `/nanonets/parse`):

```powershell
npx wrangler secret put NANONETS_API_KEY
npx wrangler secret put NANONETS_MODEL_ID
```

## Despliegue

```powershell
npx wrangler deploy
```

Al finalizar, Wrangler mostrará la URL pública: `https://<subdominio>.workers.dev`.

## Pruebas

```powershell
# Salud
curl https://<subdominio>.workers.dev/health

# Generación de recetas (ejemplo)
curl -X POST -H "Content-Type: application/json" `
  -d "{\"ingredients\":[\"pasta\",\"tomate\",\"aceite\",\"sal\"]}" `
  https://<subdominio>.workers.dev/recipes/generate

# Nanonets proxy (ejemplo con URL)
curl -X POST -H "Content-Type: application/json" `
  -d "{\"imageUrl\":\"https://.../ticket.jpg\"}" `
  https://<subdominio>.workers.dev/nanonets/parse

# Nanonets proxy (ejemplo con base64)
curl -X POST -H "Content-Type: application/json" `
  -d "{\"imageBase64\":\"<BASE64>\"}" `
  https://<subdominio>.workers.dev/nanonets/parse
```

## Integración con Flutter

Edita `lib/config.dart` en la app y actualiza:

```dart
static const String recipesAiUrl = 'https://<subdominio>.workers.dev/recipes/generate';
```

La pantalla `lib/screens/recipes_screen.dart` usa este endpoint al pulsar el botón “Generar con IA”.

## Notas de seguridad

- No expongas claves en el repositorio ni en CLI compartidos.
- Tras pruebas, considera rotar el token de Cloudflare y la API Key de Gemini.
