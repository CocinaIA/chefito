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

	const apiKey = env.GOOGLE_API_KEY;
	if (!apiKey) {
		return json({ error: 'Missing GOOGLE_API_KEY secret' }, 500);
	}

	// Prompt con contrato JSON (mensaje único para mayor compatibilidad)
	const prompt = `Eres un asistente culinario.
Responde SOLO con JSON válido exactamente con esta estructura:
{"recipes":[{"title":"string","used":["string"],"missing":["string"],"steps":["string"]}]}
Reglas:
- Máximo ${max} recetas.
- Maximiza uso de ingredientes disponibles.
- Usa términos simples y pasos breves.
- No incluyas marcas.
Ingredientes disponibles: ${ingredients.join(', ')}
Preferencias: ${JSON.stringify(prefs)}
Devuelve SOLO JSON siguiendo el esquema. Nada de texto adicional.`;

	// Build request payload once
	const payload = {
		contents: [{ role: 'user', parts: [{ text: prompt }] }],
		generationConfig: { temperature: 0.2, topP: 0.9, maxOutputTokens: 2048 },
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
		// Prefer code-fence extraction if present
		const m = text.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
		let candidate = m ? m[1] : text;
		// Normalize smart quotes and remove trailing commas
		candidate = candidate
			.replace(/[\u201C\u201D]/g, '"')
			.replace(/[\u2018\u2019]/g, "'")
			.replace(/,\s*([}\]])/g, '$1');
		parsed = JSON.parse(candidate);
	} catch (e) {
		// Fallback: attempt to extract the longest balanced JSON object
		const extractBalancedTop = (s) => {
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
					else if (ch === '}') { depth--; if (depth === 0) return s.slice(start, i + 1); }
				}
			}
			return null;
		};

		let candidate = extractBalancedTop(text) || (text.match(/\{[\s\S]*\}/)?.[0] ?? null);
		if (!candidate) {
			// Advanced fallback: collect inner balanced objects (e.g., individual recipes) and wrap them
			const objects = [];
			let inStr = false, esc = false, depth = 0, startIdx = -1;
			for (let i = 0; i < text.length; i++) {
				const ch = text[i];
				if (inStr) {
					if (esc) esc = false; else if (ch === '\\') esc = true; else if (ch === '"') inStr = false;
				} else {
					if (ch === '"') inStr = true;
					else if (ch === '{') { if (depth === 0) startIdx = i; depth++; }
					else if (ch === '}') { depth--; if (depth === 0 && startIdx !== -1) { objects.push(text.slice(startIdx, i + 1)); startIdx = -1; } }
				}
			}
			if (objects.length) {
				const parsedObjects = [];
				for (const objStr of objects) {
					try { parsedObjects.push(JSON.parse(objStr)); } catch {}
				}
				if (parsedObjects.length) {
					parsed = { recipes: parsedObjects.map(o => ({
						title: String(o.title || o.name || '').trim(),
						used: Array.isArray(o.used) ? o.used : [],
						missing: Array.isArray(o.missing) ? o.missing : [],
						steps: Array.isArray(o.steps) ? o.steps : (Array.isArray(o.instructions) ? o.instructions : []),
					})).slice(0, max) };
				}
			}
		}
		if (!parsed) {
			candidate = (candidate || '').replace(/,\s*([}\]])/g, '$1');
			try { parsed = JSON.parse(candidate); } catch (e2) {
				return json({ error: 'Invalid JSON from model', raw: text }, 502);
			}
		}
	}

	// Basic validation
	const recipes = Array.isArray(parsed.recipes) ? parsed.recipes : [];
	for (const r of recipes) {
		r.title = String(r.title || '').trim();
		r.used = Array.isArray(r.used) ? r.used.map(String) : [];
		r.missing = Array.isArray(r.missing) ? r.missing.map(String) : [];
		r.steps = Array.isArray(r.steps) ? r.steps.map(String) : [];
	}

	return json({ recipes });
}

async function handleListModels(env) {
	const apiKey = env.GOOGLE_API_KEY;
	if (!apiKey) return json({ error: 'Missing GOOGLE_API_KEY secret' }, 500);
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
	return json({ ingredients, raw: data, count: ingredients.length });
}

function extractIngredientsFromNanonets(raw) {
	const out = new Set();
	const results = Array.isArray(raw?.result) ? raw.result : [];
	for (const r of results) {
		const preds = Array.isArray(r?.prediction) ? r.prediction : [];
		// Try table-style fields: description/product_code with optional quantity
		const rows = new Map(); // rowIndex -> { description, quantity }
		for (const p of preds) {
			const label = String(p?.label || '').toLowerCase();
			const text = String(p?.ocr_text || p?.text || p?.value || '').trim();
			if (!text) continue;
			const rowIndex = p?.row_index ?? p?.cells?.[0]?.row ?? 0;
			const row = rows.get(rowIndex) || {};
			if (label === 'description' || label === 'product_code' || label === 'item' || label === 'name') {
				row.description = (row.description ? row.description + ' ' : '') + text;
			} else if (label === 'quantity' || label === 'qty') {
				row.quantity = text;
			}
			rows.set(rowIndex, row);
		}
		for (const [, row] of rows) {
			if (row.description) {
				const ingredient = row.quantity ? `${row.description} (${row.quantity})` : row.description;
				pushCandidate(out, ingredient);
			}
		}
		// Fallback to text_blocks
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

