import { env, createExecutionContext, waitOnExecutionContext, SELF } from 'cloudflare:test';
import { describe, it, expect } from 'vitest';
import worker from '../src';

describe('Chefito Worker', () => {
	it('GET /health returns ok:true (unit)', async () => {
		const request = new Request('http://example.com/health');
		const ctx = createExecutionContext();
		const response = await worker.fetch(request, env, ctx);
		await waitOnExecutionContext(ctx);
		expect(response.status).toBe(200);
		const data = await response.json();
		expect(data.ok).toBe(true);
		expect(data.service).toBe('chefito-worker');
	});

	it('GET /health returns ok:true (integration)', async () => {
		const response = await SELF.fetch('http://example.com/health');
		expect(response.status).toBe(200);
		const data = await response.json();
		expect(data.ok).toBe(true);
	});
});
