const express = require('express');
const store = require('../store');

const router = express.Router();

// GET /api/tasks?completed=true|false
router.get('/', (req, res) => {
  const { completed } = req.query;
  const tasks = store.getAll({ completed });
  res.status(200).json(tasks);
});

// POST /api/tasks
router.post('/', (req, res) => {
  const { valid, errors } = store.validateCreate(req.body);
  if (!valid) {
    return res.status(400).json({ errors });
  }
  const task = store.create(req.body);
  res.status(201).json(task);
});

// GET /api/tasks/:id
router.get('/:id', (req, res) => {
  const id = Number(req.params.id);
  const task = store.getById(id);
  if (!task) {
    return res.status(404).json({ error: `Task ${id} not found` });
  }
  res.status(200).json(task);
});

// PUT /api/tasks/:id
router.put('/:id', (req, res) => {
  const id = Number(req.params.id);
  try {
    const task = store.update(id, req.body);
    if (!task) {
      return res.status(404).json({ error: `Task ${id} not found` });
    }
    res.status(200).json(task);
  } catch (err) {
    res.status(400).json({ errors: [err.message] });
  }
});

// DELETE /api/tasks/:id
router.delete('/:id', (req, res) => {
  const id = Number(req.params.id);
  const removed = store.remove(id);
  if (!removed) {
    return res.status(404).json({ error: `Task ${id} not found` });
  }
  res.status(204).send();
});

module.exports = router;
