const request = require('supertest');
const app = require('../app');

describe('Sample App', () => {
  it('should return hello message', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toEqual(200);
    expect(res.body.message).toContain('Hello');
  });

  it('health check should return OK', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toEqual(200);
    expect(res.body.status).toEqual('OK');
  });
});
