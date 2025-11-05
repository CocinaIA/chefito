export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders() });
    }
    try {
      const { imageUrl, imageBase64, modelId } = await request.json();
      if (!imageUrl && !imageBase64) {
        return json({ error: 'Provide imageUrl or imageBase64' }, 400);
      }
      const apiKey = env.NANONETS_API_KEY;
      const model = modelId || env.NANONETS_MODEL_ID;
      if (!apiKey || !model) {
        return json({ error: 'Missing secrets' }, 500);
      }

      const endpoint = `https://app.nanonets.com/api/v2/OCR/Model/${model}/LabelFile/`;
      let resp;
      if (imageUrl) {
        resp = await fetch(endpoint, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Basic ' + btoa(apiKey + ':'),
          },
          body: JSON.stringify({ urls: [imageUrl] }),
        });
      } else {
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
        return json({ error: 'Nanonets error', detail: await resp.text() }, resp.status);
      }

      const raw = await resp.json();
      const ingredients = extractIngredients(raw);
      return json({ ingredients, raw });
    } catch (e) {
      return json({ error: String(e) }, 500);
    }
  }
};

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
  };
}
function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders() },
  });
}
function extractIngredients(raw) {
  const out = new Set();
  const result = raw?.result?.[0];
  if (Array.isArray(result?.prediction)) {
    for (const p of result.prediction) {
      const label = (p?.label || '').toLowerCase();
      const value = (p?.ocr_text || p?.value || '').toString().trim();
      if (value && /(item|description|product|name)/.test(label)) pushLines(out, value);
    }
  }
  if (Array.isArray(result?.line_items)) {
    for (const li of result.line_items) {
      const desc = (li?.description || li?.item || li?.name || '').toString().trim();
      if (desc) pushLines(out, desc);
    }
  }
  if (Array.isArray(result?.text_blocks)) {
    for (const tb of result.text_blocks) {
      const text = (tb?.text || '').toString();
      pushLines(out, text);
    }
  }
  return Array.from(out);
}
function pushLines(set, text) {
  for (const p of text.split(/\r?\n/).map(s => s.trim()).filter(Boolean)) {
    if (/(\d+[\.,]\d{2})|€|total|iva|subtotal|pago|cambio|x\d+/i.test(p)) continue;
    const cleaned = p.replace(/[^A-Za-zÁÉÍÓÚáéíóúÑñ\s]/g, '').trim();
    if (cleaned) set.add(cleaned);
  }
}