const request = require('supertest');
const app = require('../src/app');
const store = require('../src/store');

// Start each test with a clean in-memory store so tests don't leak state
// into each other.
beforeEach(() => {
  store.resetStore();
});

describe('POST /api/tasks', () => {
  it('creates a task and returns 201 with the created object', async () => {
    const res = await request(app)
      .post('/api/tasks')
      .send({ title: 'Write capstone docs', description: 'Phase 1 deliverables' });

    expect(res.statusCode).toBe(201);
    expect(res.body).toMatchObject({
      id: expect.any(Number),
      title: 'Write capstone docs',
      description: 'Phase 1 deliverables',
      completed: false,
    });
  });

  it('rejects a task with no title with 400', async () => {
    const res = await request(app).post('/api/tasks').send({ description: 'no title' });

    expect(res.statusCode).toBe(400);
    expect(res.body.errors).toContain('title is required and must be a non-empty string');
  });

  it('rejects a title longer than 100 characters', async () => {
    const longTitle = 'a'.repeat(101);
    const res = await request(app).post('/api/tasks').send({ title: longTitle });

    expect(res.statusCode).toBe(400);
    expect(res.body.errors).toContain('title must be 100 characters or fewer');
  });

  it('trims whitespace from the title', async () => {
    const res = await request(app).post('/api/tasks').send({ title: '  Trimmed  ' });

    expect(res.statusCode).toBe(201);
    expect(res.body.title).toBe('Trimmed');
  });
});

describe('GET /api/tasks', () => {
  it('returns an empty array when no tasks exist', async () => {
    const res = await request(app).get('/api/tasks');

    expect(res.statusCode).toBe(200);
    expect(res.body).toEqual([]);
  });

  it('returns all created tasks', async () => {
    await request(app).post('/api/tasks').send({ title: 'Task A' });
    await request(app).post('/api/tasks').send({ title: 'Task B' });

    const res = await request(app).get('/api/tasks');

    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveLength(2);
  });

  it('filters by completed status', async () => {
    const created = await request(app).post('/api/tasks').send({ title: 'Done task' });
    await request(app).put(`/api/tasks/${created.body.id}`).send({ completed: true });
    await request(app).post('/api/tasks').send({ title: 'Pending task' });

    const completedRes = await request(app).get('/api/tasks?completed=true');
    const pendingRes = await request(app).get('/api/tasks?completed=false');

    expect(completedRes.body).toHaveLength(1);
    expect(completedRes.body[0].title).toBe('Done task');
    expect(pendingRes.body).toHaveLength(1);
    expect(pendingRes.body[0].title).toBe('Pending task');
  });
});

describe('GET /api/tasks/:id', () => {
  it('returns the task when it exists', async () => {
    const created = await request(app).post('/api/tasks').send({ title: 'Find me' });

    const res = await request(app).get(`/api/tasks/${created.body.id}`);

    expect(res.statusCode).toBe(200);
    expect(res.body.title).toBe('Find me');
  });

  it('returns 404 when the task does not exist', async () => {
    const res = await request(app).get('/api/tasks/9999');

    expect(res.statusCode).toBe(404);
    expect(res.body.error).toBe('Task 9999 not found');
  });
});

describe('PUT /api/tasks/:id', () => {
  it('updates fields on an existing task', async () => {
    const created = await request(app).post('/api/tasks').send({ title: 'Original' });

    const res = await request(app)
      .put(`/api/tasks/${created.body.id}`)
      .send({ title: 'Updated', completed: true });

    expect(res.statusCode).toBe(200);
    expect(res.body.title).toBe('Updated');
    expect(res.body.completed).toBe(true);
  });

  it('returns 404 when updating a task that does not exist', async () => {
    const res = await request(app).put('/api/tasks/9999').send({ title: 'Nope' });

    expect(res.statusCode).toBe(404);
  });

  it('returns 400 when updating with an empty title', async () => {
    const created = await request(app).post('/api/tasks').send({ title: 'Original' });

    const res = await request(app)
      .put(`/api/tasks/${created.body.id}`)
      .send({ title: '   ' });

    expect(res.statusCode).toBe(400);
  });
});

describe('DELETE /api/tasks/:id', () => {
  it('deletes an existing task and returns 204', async () => {
    const created = await request(app).post('/api/tasks').send({ title: 'Delete me' });

    const res = await request(app).delete(`/api/tasks/${created.body.id}`);
    expect(res.statusCode).toBe(204);

    const getRes = await request(app).get(`/api/tasks/${created.body.id}`);
    expect(getRes.statusCode).toBe(404);
  });

  it('returns 404 when deleting a task that does not exist', async () => {
    const res = await request(app).delete('/api/tasks/9999');

    expect(res.statusCode).toBe(404);
  });
});
