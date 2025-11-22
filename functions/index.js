import { onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import axios from 'axios';
import FormData from 'form-data';

// Secrets (set with `firebase functions:secrets:set ...`)
const NANONETS_API_KEY = defineSecret('NANONETS_API_KEY');
const NANONETS_MODEL_ID = defineSecret('NANONETS_MODEL_ID');

export const nanonetsParseReceipt = onCall(
  { region: 'us-central1', secrets: [NANONETS_API_KEY, NANONETS_MODEL_ID] },
  async (request) => {
    try {
      const data = request?.data || {};
      const imageUrl = typeof data.imageUrl === 'string' && data.imageUrl.trim() ? data.imageUrl.trim() : undefined;
      const imageBase64 = typeof data.imageBase64 === 'string' && data.imageBase64.trim() ? data.imageBase64.trim() : undefined;
      const modelId = data.modelId || NANONETS_MODEL_ID.value();
      const apiKey = NANONETS_API_KEY.value();

      if (!imageUrl && !imageBase64) {
        throw new Error('Provide imageUrl or imageBase64');
      }
      if (!apiKey || !modelId) {
        throw new Error('Missing NANONETS_API_KEY or NANONETS_MODEL_ID');
      }

      const endpoint = `https://app.nanonets.com/api/v2/OCR/Model/${modelId}/LabelFile/?async=false`;

      let resp;
      if (imageUrl) {
        // Send as multipart/form-data for compatibility
        const form = new FormData();
        form.append('urls', imageUrl);
        resp = await axios.post(endpoint, form, {
          headers: {
            ...form.getHeaders(),
            Authorization: 'Basic ' + Buffer.from(apiKey + ':').toString('base64'),
          },
          validateStatus: () => true,
        });
      } else {
        const bin = Buffer.from(imageBase64, 'base64');
        const form = new FormData();
        form.append('file', bin, { filename: 'receipt.jpg', contentType: 'image/jpeg' });
        resp = await axios.post(endpoint, form, {
          headers: {
            ...form.getHeaders(),
            Authorization: 'Basic ' + Buffer.from(apiKey + ':').toString('base64'),
          },
          maxBodyLength: Infinity,
          validateStatus: () => true,
        });
      }

      if (!resp || resp.status < 200 || resp.status >= 300) {
        const detail = resp?.data || resp?.statusText || 'Unknown';
        return { error: 'Nanonets error', status: resp?.status || 502, detail };
      }

      const raw = resp.data || {};
      const ingredients = extractIngredients(raw);
      return { ingredients, raw };
    } catch (e) {
      return { error: e?.message || String(e) };
    }
  }
);

function extractIngredients(raw) {
  const out = new Set();
  const results = Array.isArray(raw?.result) ? raw.result : [];
  for (const r of results) {
    const preds = Array.isArray(r?.prediction) ? r.prediction : [];
    const rows = new Map();
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
    if (/(\d+[\.,]\d{2})|€|total|iva|subtotal|pago|cambio|x\d+/i.test(p)) continue;
    const cleaned = p.replace(/[^A-Za-zÁÉÍÓÚáéíóúÑñ\s]/g, '').trim();
    if (cleaned) set.add(cleaned);
  }
}