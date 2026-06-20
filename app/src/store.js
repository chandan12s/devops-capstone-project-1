/**
 * In-memory Task store.
 *
 * In a real production system this would be a database (Postgres, DynamoDB,
 * etc). We use memory here to keep the capstone project simple, but the
 * validation logic and error handling are written exactly as they would be
 * against a real datastore, so the API behavior is realistic.
 */

let tasks = [];
let nextId = 1;

function resetStore() {
  // Exposed only for tests, so each test file starts from a clean state.
  tasks = [];
  nextId = 1;
}

function getAll({ completed } = {}) {
  if (completed === undefined) return tasks;
  const wantCompleted = completed === 'true';
  return tasks.filter((t) => t.completed === wantCompleted);
}

function getById(id) {
  return tasks.find((t) => t.id === id);
}

/**
 * Validates raw input for creating a task.
 * Returns { valid: boolean, errors: string[] }
 */
function validateCreate(data) {
  const errors = [];
  if (!data || typeof data.title !== 'string' || data.title.trim().length === 0) {
    errors.push('title is required and must be a non-empty string');
  } else if (data.title.length > 100) {
    errors.push('title must be 100 characters or fewer');
  }
  if (data && data.description !== undefined && typeof data.description !== 'string') {
    errors.push('description must be a string if provided');
  }
  return { valid: errors.length === 0, errors };
}

function create(data) {
  const task = {
    id: nextId++,
    title: data.title.trim(),
    description: data.description ? data.description.trim() : '',
    completed: false,
    createdAt: new Date().toISOString(),
  };
  tasks.push(task);
  return task;
}

function update(id, data) {
  const task = getById(id);
  if (!task) return null;

  if (data.title !== undefined) {
    if (typeof data.title !== 'string' || data.title.trim().length === 0) {
      throw new Error('title must be a non-empty string');
    }
    task.title = data.title.trim();
  }
  if (data.description !== undefined) {
    task.description = String(data.description).trim();
  }
  if (data.completed !== undefined) {
    task.completed = Boolean(data.completed);
  }
  return task;
}

function remove(id) {
  const index = tasks.findIndex((t) => t.id === id);
  if (index === -1) return false;
  tasks.splice(index, 1);
  return true;
}

module.exports = {
  getAll,
  getById,
  validateCreate,
  create,
  update,
  remove,
  resetStore,
};
