/**
 * Welcome to Cloudflare Workers! This is your first worker.
 *
 * - Run `npm run dev` in your terminal to start a development server
 * - Open a browser tab at http://localhost:8787/ to see your worker in action
 * - Run `npm run deploy` to publish your worker
 *
 * Learn more at https://developers.cloudflare.com/workers/
 */

// Cloudflare Worker: Nanonets proxy (existing) + AI recipe generation endpoint

export default {
	async fetch(request, env, ctx) {
		const url = new URL(request.url);

		// CORS preflight
		if (request.method === 'OPTIONS') {
			return new Response(null, { headers: corsHeaders() });
		}

		try {
			if (url.pathname === '/' || url.pathname === '/health') {
				return json({ ok: true, service: 'chefito-worker' });
			}

			if (url.pathname === '/models' && request.method === 'GET') {
				return await handleListModels(env);
			}

			// Nanonets proxy endpoint: POST /nanonets/parse
			if (url.pathname === '/nanonets/parse' && request.method === 'POST') {
				return await handleNanonetsParse(request, env);
			}

			if (url.pathname === '/recipes/generate' && request.method === 'POST') {
				return await handleGenerateRecipes(request, env);
			}

			return json({ error: 'Not found' }, 404);
		} catch (e) {
			return json({ error: String(e) }, 500);
		}
	},
};

function corsHeaders() {
	return {
		'Access-Control-Allow-Origin': '*',
		'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
		'Access-Control-Allow-Headers': 'Content-Type,Authorization',
	};
}

function json(obj, status = 200) {
	return new Response(JSON.stringify(obj), {
		status,
		headers: { 'Content-Type': 'application/json', ...corsHeaders() },
	});
}

async function handleGenerateRecipes(request, env) {
	// Read raw body for debugging/logging and then parse JSON
	const raw = await request.text().catch(() => '');
	let body;
	try {
		body = raw ? JSON.parse(raw) : {};
	} catch (e) {
		console.log('Invalid JSON body', { raw });
		return json({ error: 'Invalid JSON', detail: String(e) }, 400);
	}
	console.log('Incoming /recipes/generate body', { body });
	const ingredients = Array.isArray(body.ingredients) ? body.ingredients : [];
	const max = Math.min(Number(body.max ?? 3) || 3, 10);
	const prefs = body.prefs || {};

	if (!ingredients.length) {
		return json({ error: 'ingredients must be a non-empty string[]' }, 400);
	}

	// Google Gemini API Key (public key for development)
	const apiKey = 'AIzaSyBr12dPL50ec23cdDv0My9I_L4ZcpiP6Qo';
	if (!apiKey) {
		return json({ error: 'Missing GOOGLE_API_KEY' }, 500);
	}

	// Prompt con contrato JSON mejorado para recetas detalladas EN ESPAÑOL
	const prompt = `Eres un chef experto. Crea recetas DETALLADAS, ESPECÍFICAS y COMPLETAS en español.
Responde SOLO con JSON válido. SIN markdown, SIN comillas invertidas.
Estructura JSON EXACTA:
{
  "recipes": [
    {
      "title": "Nombre de la receta",
      "description": "Descripción de 1-2 líneas del plato",
      "servings": "número de porciones",
      "time": "tiempo total de cocción (ej: 30 minutos)",
      "difficulty": "fácil/medio/difícil",
      "used": ["300g arroz", "2 huevos", "100ml aceite", "1 cebolla"],
      "missing": ["ingrediente opcional para mejor sabor"],
      "steps": [
        "PASO 1 (PREPARACIÓN): Descripción muy específica de qué cortar, cómo preparar. Incluye tamaños exactos (dados, picado fino, rodajas de 1cm, etc). Tiempo estimado.",
        "PASO 2 (COCCIÓN): Temperaturas exactas, tiempos precisos, y qué buscar. Ejemplo: 'Calienta el aceite a 180°C (o hasta que brille), agrega ingredientes y fríe durante 3-4 minutos hasta que...'",
        "PASO 3 (CONTINUACIÓN): Instrucciones detalladas con temperaturas, tiempos específicos y señales sensoriales (color, olor, textura)",
        "PASO 4 (ACABADO): Toques finales, presentación y cómo servir",
        "PASO 5 (OPCIONAL): Pasos adicionales si se necesitan para completar la receta"
      ],
      "tips": ["Consejo profesional 1", "Error común a evitar", "Variación de sabor"],
      "variations": ["Sustitución de ingredientes alternativa", "Método de cocción diferente"]
    }
  ]
}
REQUISITOS CRÍTICOS:
- Responde EN ESPAÑOL. Todos los pasos, títulos y descripciones deben estar en español.
- Cada paso DEBE ser completo (3-4 oraciones mínimo) con detalles específicos
- Incluye temperaturas exactas en Celsius cuando sea relevante
- Incluye tiempos precisos para cada paso (ej: "cocina durante 8-10 minutos hasta que esté dorado")
- Describe señales sensoriales: color, olor, textura, sonido (ej: "escucharás un chasquido", "debe oler intenso")
- Sé muy específico en los cortes: dados, picado fino, rodajas de 1cm, juliana, etc.
- Incluye técnicas profesionales de cocina
- CRÍTICO: Array "used" DEBE incluir CANTIDADES EXACTAS con unidades (ej: "300g arroz", "2 huevos", "100ml aceite")
- Formato "used": "CANTIDAD UNIDAD INGREDIENTE" (ej: "50g mantequilla", "3 dientes ajo", "250ml leche")
- NO incluyas rangos (usa "300g" no "300-350g")
- Máximo ${max} recetas
- Maximiza el uso de ingredientes disponibles
- Cada receta debe tener al menos 5 pasos detallados y 1 ingrediente con cantidad
- Incluye tamaño de porción y tiempo total
- Nivel de dificultad: fácil (sin habilidades especiales), medio (habilidades básicas), difícil (técnicas avanzadas)
Ingredientes disponibles: ${ingredients.join(', ')}
Preferencias: ${JSON.stringify(prefs)}
Responde SOLO con el JSON. Nada más. Sin explicaciones.`;

	// Build request payload once
	const payload = {
		contents: [{ role: 'user', parts: [{ text: prompt }] }],
		generationConfig: { temperature: 0.3, topP: 0.85, maxOutputTokens: 4096 },
	};

	// Helper to call Gemini with version+model
	const callGemini = async (apiVersion, modelName) => {
		const endpoint = `https://generativelanguage.googleapis.com/${apiVersion}/models/${modelName}:generateContent?key=${encodeURIComponent(apiKey)}`;
		const resp = await fetch(endpoint, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(payload),
		});
		let text = '';
		let data = null;
		let detail = '';
		if (!resp.ok) {
			detail = await resp.text().catch(() => '');
			return { ok: false, status: resp.status, detail, model: modelName, apiVersion };
		}
		data = await resp.json().catch(() => ({}));
		const parts = data?.candidates?.[0]?.content?.parts || [];
		text = parts.map((p) => p?.text || '').join('\n').trim();
		if (!text) {
			const feedback = data?.promptFeedback || data;
			return { ok: false, status: 502, detail: JSON.stringify(feedback), model: modelName, apiVersion };
		}
		return { ok: true, text, data, model: modelName, apiVersion };
	};

	// Candidate list: try user model on v1 then v1beta, then known-good fallbacks
	const userModel = typeof body.model === 'string' && body.model.trim() ? body.model.trim() : null;
	// Prefer v1 models visible in /models, then older 1.5 variants
	const fallbackV1 = ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-2.0-flash-001', 'gemini-1.5-flash-001', 'gemini-1.5-pro-001'];
	const fallbackV1beta = ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-1.5-flash-latest', 'gemini-1.5-pro-latest'];
	const tried = new Set();
	const candidates = [];
	if (userModel) {
		candidates.push({ v: 'v1', m: userModel });
		candidates.push({ v: 'v1beta', m: userModel });
	}
	for (const m of fallbackV1) candidates.push({ v: 'v1', m });
	for (const m of fallbackV1beta) candidates.push({ v: 'v1beta', m });

	let lastErrors = [];
	let text = '';
	let data = null;
	for (const c of candidates) {
		const key = `${c.v}:${c.m}`;
		if (tried.has(key)) continue;
		tried.add(key);
		const r = await callGemini(c.v, c.m);
		if (r.ok && r.text) {
			text = r.text;
			data = r.data;
			console.log(`Gemini success using ${c.v}/${c.m}`);
			break;
		}
		lastErrors.push({ model: c.m, api: c.v, status: r.status, detail: r.detail?.slice(0, 500) });
	}

	if (!text) {
		console.log('All Gemini attempts failed', JSON.stringify(lastErrors));
		return json({ error: 'Gemini failed for all candidates', attempts: lastErrors }, 502);
	}

	let parsed;
	try {
		// Step 1: Try to extract JSON from code fences (markdown style)
		const codeFenceMatch = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
		let candidate = codeFenceMatch ? codeFenceMatch[1] : text;
		
		// Step 2: Normalize special characters
		candidate = candidate
			.replace(/[\u201C\u201D]/g, '"')  // Smart quotes
			.replace(/[\u2018\u2019]/g, "'")
			.replace(/,\s*([}\]])/g, '$1');    // Trailing commas
		
		// Step 3: Try direct parse
		parsed = JSON.parse(candidate);
	} catch (e) {
		console.log('Direct JSON parse failed, attempting extraction', { error: e.message });
		
		// Fallback: Try to extract the most complete balanced JSON object
		const extractBalancedJSON = (s) => {
			// Find first {
			const start = s.indexOf('{');
			if (start === -1) return null;
			
			let depth = 0, inStr = false, esc = false;
			for (let i = start; i < s.length; i++) {
				const ch = s[i];
				if (inStr) {
					if (esc) esc = false;
					else if (ch === '\\') esc = true;
					else if (ch === '"') inStr = false;
				} else {
					if (ch === '"') inStr = true;
					else if (ch === '{') depth++;
					else if (ch === '}') { 
						depth--; 
						if (depth === 0) return s.slice(start, i + 1); 
					}
				}
			}
			return null;
		};

		let balanced = extractBalancedJSON(text);
		if (balanced) {
			try {
				balanced = balanced.replace(/[\u201C\u201D]/g, '"').replace(/[\u2018\u2019]/g, "'").replace(/,\s*([}\]])/g, '$1');
				parsed = JSON.parse(balanced);
			} catch (e2) {
				console.log('Balanced extraction failed', { error: e2.message });
				balanced = null;
			}
		}

		// If still no parsed object, try collecting individual recipe objects
		if (!parsed) {
			console.log('Attempting to extract individual recipe objects');
			const objects = [];
			let inStr = false, esc = false, depth = 0, startIdx = -1;
			
			for (let i = 0; i < text.length; i++) {
				const ch = text[i];
				if (inStr) {
					if (esc) esc = false; 
					else if (ch === '\\') esc = true; 
					else if (ch === '"') inStr = false;
				} else {
					if (ch === '"') inStr = true;
					else if (ch === '{') { 
						if (depth === 0) startIdx = i; 
						depth++; 
					}
					else if (ch === '}') { 
						depth--; 
						if (depth === 0 && startIdx !== -1) { 
							objects.push(text.slice(startIdx, i + 1)); 
							startIdx = -1; 
						} 
					}
				}
			}

			if (objects.length) {
				console.log(`Found ${objects.length} potential recipe objects`);
				const parsedObjects = [];
				for (const objStr of objects) {
					try { 
						const normalized = objStr.replace(/[\u201C\u201D]/g, '"').replace(/[\u2018\u2019]/g, "'").replace(/,\s*([}\]])/g, '$1');
						const obj = JSON.parse(normalized); 
						parsedObjects.push(obj);
					} catch (e3) {
						// Skip objects that don't parse
						console.log('Skipping unparseable object');
					}
				}

				if (parsedObjects.length) {
					console.log(`Successfully parsed ${parsedObjects.length} recipe objects`);
					parsed = { 
						recipes: parsedObjects
							.map(o => ({
								title: String(o.title || o.name || '').trim() || 'Receta sin nombre',
								description: String(o.description || '').trim() || '',
								servings: String(o.servings || '').trim() || '',
								time: String(o.time || '').trim() || '',
								difficulty: String(o.difficulty || '').trim() || 'medium',
								used: Array.isArray(o.used) ? o.used.map(String).filter(s => s.trim()) : [],
								missing: Array.isArray(o.missing) ? o.missing.map(String).filter(s => s.trim()) : [],
								steps: Array.isArray(o.steps) ? o.steps.map(String).filter(s => s.trim()) : (Array.isArray(o.instructions) ? o.instructions.map(String).filter(s => s.trim()) : []),
								tips: Array.isArray(o.tips) ? o.tips.map(String).filter(s => s.trim()) : [],
								variations: Array.isArray(o.variations) ? o.variations.map(String).filter(s => s.trim()) : [],
							}))
							.filter(r => r.title && (r.used.length > 0 || r.steps.length > 0))  // Only valid recipes
							.slice(0, max) 
					};
				}
			}
		}

		// Last resort: if nothing worked, return error with raw text for debugging
		if (!parsed) {
			console.log('All parsing attempts failed');
			return json({ error: 'Invalid JSON from model', raw: text.slice(0, 1000) }, 502);
		}
	}

	// Final validation and normalization
	const recipes = Array.isArray(parsed.recipes) ? parsed.recipes : [];
	for (const r of recipes) {
		r.title = String(r.title || '').trim() || 'Receta';
		r.description = String(r.description || '').trim() || '';
		r.servings = String(r.servings || '').trim() || '';
		r.time = String(r.time || '').trim() || '';
		r.difficulty = String(r.difficulty || 'medium').trim() || 'medium';
		r.used = Array.isArray(r.used) ? r.used.map(String).filter(s => s.trim()) : [];
		r.missing = Array.isArray(r.missing) ? r.missing.map(String).filter(s => s.trim()) : [];
		r.steps = Array.isArray(r.steps) ? r.steps.map(String).filter(s => s.trim()) : [];
		r.tips = Array.isArray(r.tips) ? r.tips.map(String).filter(s => s.trim()) : [];
		r.variations = Array.isArray(r.variations) ? r.variations.map(String).filter(s => s.trim()) : [];
	}

	// Remove duplicates and filter empty recipes
	const validRecipes = recipes.filter(r => r.title && (r.used.length > 0 || r.steps.length > 0)).slice(0, max);
	
	return json({ recipes: validRecipes });
}

async function handleListModels(env) {
	// Google Gemini API Key (public key for development)
	const apiKey = 'AIzaSyBr12dPL50ec23cdDv0My9I_L4ZcpiP6Qo';
	if (!apiKey) return json({ error: 'Missing GOOGLE_API_KEY' }, 500);
	const url = `https://generativelanguage.googleapis.com/v1/models?key=${encodeURIComponent(apiKey)}`;
	const resp = await fetch(url);
	const body = await resp.json().catch(() => ({}));
	if (!resp.ok) return json({ error: 'ListModels failed', status: resp.status, detail: body }, resp.status);
	const names = Array.isArray(body.models) ? body.models.map(m => m.name) : [];
	return json({ models: names });
}

// Proxy Nanonets OCR: accepts { imageUrl?: string, imageBase64?: string }
// Secrets required: NANONETS_API_KEY, NANONETS_MODEL_ID
async function handleNanonetsParse(request, env) {
	// Parse body safely
	const raw = await request.text().catch(() => '');
	let body;
	try {
		body = raw ? JSON.parse(raw) : {};
	} catch (e) {
		return json({ error: 'Invalid JSON', detail: String(e) }, 400);
	}

	const imageUrl = typeof body.imageUrl === 'string' && body.imageUrl.trim() ? body.imageUrl.trim() : undefined;
	const imageBase64 = typeof body.imageBase64 === 'string' && body.imageBase64.trim() ? body.imageBase64.trim() : undefined;
	if (!imageUrl && !imageBase64) {
		return json({ error: 'Provide imageUrl or imageBase64' }, 400);
	}

	const apiKey = env.NANONETS_API_KEY;
	const modelId = env.NANONETS_MODEL_ID;
	if (!apiKey || !modelId) {
		return json({ error: 'Missing NANONETS_API_KEY or NANONETS_MODEL_ID' }, 500);
	}

	const endpoint = `https://app.nanonets.com/api/v2/OCR/Model/${modelId}/LabelFile/?async=false`;

	let resp;
	if (imageUrl) {
		// When URL is provided we can use JSON body (per API) or FormData; use JSON for simplicity
		resp = await fetch(endpoint, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				'Authorization': 'Basic ' + btoa(apiKey + ':'),
			},
			body: JSON.stringify({ urls: [imageUrl] }),
		});
	} else {
		// imageBase64 path uses multipart/form-data with Blob
		const bin = Uint8Array.from(atob(imageBase64), c => c.charCodeAt(0));
		const form = new FormData();
		form.append('file', new Blob([bin], { type: 'image/jpeg' }), 'receipt.jpg');
		resp = await fetch(endpoint, {
			method: 'POST',
			headers: { 'Authorization': 'Basic ' + btoa(apiKey + ':') },
			body: form,
		});
	}

	if (!resp.ok) {
		return json({ error: 'Nanonets error', status: resp.status, detail: await resp.text() }, resp.status);
	}

	const data = await resp.json().catch(() => ({}));
	// Extract ingredients heuristically from Nanonets response
	const ingredients = extractIngredientsFromNanonets(data);
	
	// Log para debugging
	console.log('Nanonets response structure:', JSON.stringify({
		hasResult: !!data?.result,
		resultLength: Array.isArray(data?.result) ? data.result.length : 0,
		firstResult: data?.result?.[0] ? {
			hasPrediction: !!data.result[0].prediction,
			predictionLength: Array.isArray(data.result[0].prediction) ? data.result[0].prediction.length : 0,
			firstPrediction: data.result[0].prediction?.[0],
		} : null,
		extractedCount: ingredients.length,
	}, null, 2));
	
	return json({ ingredients, raw: data, count: ingredients.length });
}

function extractIngredientsFromNanonets(raw) {
	const out = new Set();
	const results = Array.isArray(raw?.result) ? raw.result : [];
	
	for (const r of results) {
		const preds = Array.isArray(r?.prediction) ? r.prediction : [];
		
		// ESTRATEGIA 1: Extraer de CELLS (para modelos tipo tabla como el tuyo)
		for (const p of preds) {
			// Si la predicción tiene cells (estructura de tabla)
			const cells = Array.isArray(p?.cells) ? p.cells : [];
			if (cells.length > 0) {
				// Organizar por filas
				const rows = new Map();
				for (const cell of cells) {
					const label = String(cell?.label || '').toLowerCase();
					const text = String(cell?.text || '').trim();
					if (!text) continue;
					
					const rowIndex = cell?.row ?? 0;
					const row = rows.get(rowIndex) || {};
					
					if (label === 'description' || label === 'producto' || label === 'item' || label === 'name') {
						row.description = (row.description ? row.description + ' ' : '') + text;
					} else if (label === 'line_amount' || label === 'quantity' || label === 'qty' || label === 'cantidad') {
						row.quantity = text;
					}
					
					rows.set(rowIndex, row);
				}
				
				// Agregar todas las descripciones encontradas
				for (const [, row] of rows) {
					if (row.description) {
						pushCandidate(out, row.description);
					}
				}
			}
		}
		
		// ESTRATEGIA 2: Extraer textos directos de predicciones (si no hay cells)
		for (const p of preds) {
			const text = String(p?.ocr_text || p?.text || p?.value || '').trim();
			// Solo agregar si no es la palabra "table" (placeholder)
			if (text && text.toLowerCase() !== 'table') {
				pushCandidate(out, text);
			}
		}
		
		// ESTRATEGIA 3: Tabla organizada por filas (predicciones con row_index)
		const rows = new Map();
		for (const p of preds) {
			const label = String(p?.label || '').toLowerCase();
			const text = String(p?.ocr_text || p?.text || p?.value || '').trim();
			if (!text || text.toLowerCase() === 'table') continue;
			
			const rowIndex = p?.row_index ?? 0;
			const row = rows.get(rowIndex) || {};
			
			if (label === 'description' || label === 'product_code' || label === 'item' || label === 'name' || label === 'producto') {
				row.description = (row.description ? row.description + ' ' : '') + text;
			}
			
			rows.set(rowIndex, row);
		}
		
		for (const [, row] of rows) {
			if (row.description) {
				pushCandidate(out, row.description);
			}
		}
		
		// ESTRATEGIA 4: Bloques de texto (fallback final)
		const blocks = Array.isArray(r?.text_blocks) ? r.text_blocks : [];
		for (const tb of blocks) {
			const t = String(tb?.text || '').trim();
			if (t) pushCandidate(out, t);
		}
	}
	
	return Array.from(out);
}

function pushCandidate(set, text) {
	for (const line of String(text).split(/\r?\n/)) {
		const p = line.trim();
		if (!p) continue;
		// Skip prices/administrative noise
		if (/(\d+[\.,]\d{2})|€|total|iva|subtotal|pago|cambio|x\d+/i.test(p)) continue;
		const cleaned = p.replace(/[^A-Za-zÁÉÍÓÚáéíóúÑñ\s]/g, '').trim();
		if (cleaned) set.add(cleaned);
	}
}

