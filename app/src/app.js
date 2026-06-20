const express = require('express');
const tasksRouter = require('./routes/tasks');

const app = express();

app.use(express.json());

// Health check - used by Kubernetes liveness/readiness probes later
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/tasks', tasksRouter);

// 404 handler for anything else
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

module.exports = app;
