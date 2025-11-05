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
	const body = await request.json().catch(() => ({}));
	const ingredients = Array.isArray(body.ingredients) ? body.ingredients : [];
	const max = Math.min(Number(body.max ?? 5) || 5, 10);
	const prefs = body.prefs || {};

	if (!ingredients.length) {
		return json({ error: 'ingredients must be a non-empty string[]' }, 400);
	}

	const apiKey = env.GOOGLE_API_KEY;
	if (!apiKey) {
		return json({ error: 'Missing GOOGLE_API_KEY secret' }, 500);
	}

	// Prompt with strict JSON contract
	const system = `Eres un asistente culinario. Responde SOLO con JSON válido.
Estructura: {"recipes":[{"title":"string","used":["string"],"missing":["string"],"steps":["string"]}]}
Reglas:
- Máximo ${max} recetas.
- Maximiza uso de ingredientes disponibles.
- Usa términos simples y pasos breves.
- No incluyas marcas ni ingredientes exóticos si no son necesarios.`;

	const user = `Ingredientes disponibles: ${ingredients.join(', ')}
Preferencias: ${JSON.stringify(prefs)}
Devuelve SOLO JSON siguiendo el esquema. Nada de texto adicional.`;

	const endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=' + encodeURIComponent(apiKey);

	const payload = {
		contents: [
			{ role: 'user', parts: [{ text: system }] },
			{ role: 'user', parts: [{ text: user }] },
		],
		generationConfig: {
			temperature: 0.6,
			topP: 0.9,
			maxOutputTokens: 1024,
			response_mime_type: 'application/json',
		},
	};

	const resp = await fetch(endpoint, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(payload),
	});

	if (!resp.ok) {
		return json({ error: 'Gemini error', status: resp.status, detail: await resp.text() }, resp.status);
	}

	const data = await resp.json();
	const text = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
	if (!text) {
		return json({ error: 'Empty model response' }, 502);
	}

	let parsed;
	try {
		parsed = JSON.parse(text);
	} catch (e) {
		// Fallback: try to extract the first JSON block
		const m = text.match(/\{[\s\S]*\}/);
		if (!m) return json({ error: 'Model returned non-JSON', raw: text }, 502);
		try { parsed = JSON.parse(m[0]); } catch (e2) {
			return json({ error: 'Invalid JSON from model', raw: text }, 502);
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

