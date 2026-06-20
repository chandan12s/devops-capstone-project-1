const request = require('supertest');
const app = require('../src/app');

describe('GET /health', () => {
  it('returns 200 with status ok and a timestamp', async () => {
    const res = await request(app).get('/health');

    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.timestamp).toBeDefined();
    // Sanity check that timestamp is a real ISO date, not just any string
    expect(new Date(res.body.timestamp).toString()).not.toBe('Invalid Date');
  });
});
