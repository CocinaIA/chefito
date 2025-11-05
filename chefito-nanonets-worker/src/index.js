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

	// Use a model confirmed by ListModels
	const model = 'gemini-2.5-flash';
	const endpoint = `https://generativelanguage.googleapis.com/v1/models/${model}:generateContent?key=${encodeURIComponent(apiKey)}`;

	const payload = {
		contents: [
			{ role: 'user', parts: [{ text: system }] },
			{ role: 'user', parts: [{ text: user }] },
		],
		generationConfig: {
			temperature: 0.4,
			topP: 0.9,
			maxOutputTokens: 512,
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
		let text = data?.candidates?.[0]?.content?.parts?.[0]?.text || '';
	if (!text) {
		console.log('Model returned no text', JSON.stringify(data));
		return json({ error: 'Empty model response' }, 502);
	}

	let parsed;
	try {
		// Strip common code-fence wrappers like ```json ... ```
		const stripped = text
			.replace(/^```(?:json)?\s*/i, '')
			.replace(/\s*```\s*$/i, '');
		parsed = JSON.parse(stripped);
	} catch (e) {
		// Fallback: attempt to extract the longest balanced JSON object
		const extractBalanced = (s) => {
			const start = s.indexOf('{');
			if (start === -1) return null;
			let depth = 0;
			let inStr = false;
			let esc = false;
			for (let i = start; i < s.length; i++) {
				const ch = s[i];
				if (inStr) {
					if (esc) { esc = false; }
					else if (ch === '\\') { esc = true; }
					else if (ch === '"') { inStr = false; }
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
		const candidate = extractBalanced(text) || (text.match(/\{[\s\S]*\}/)?.[0] ?? null);
		if (!candidate) return json({ error: 'Model returned non-JSON', raw: text }, 502);
		try { parsed = JSON.parse(candidate); } catch (e2) {
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

