const express = require('express');
const tasksRouter = require('./routes/tasks');

const app = express();

app.use(express.json());

// Structured request logging, shipped to CloudWatch Logs via the
// CloudWatch agent (see terraform/scripts/bootstrap-k8s.sh). One JSON
// line per request, so Phase 5's "analyze errors" queries have real
// data to work with - not placeholder log lines.
// Suppressed during tests (Jest sets NODE_ENV=test) to keep test output clean.
app.use((req, res, next) => {
  const startTime = Date.now();
  res.on('finish', () => {
    if (process.env.NODE_ENV === 'test') return;
    const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';
    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      level,
      method: req.method,
      path: req.originalUrl,
      statusCode: res.statusCode,
      durationMs: Date.now() - startTime,
    }));
  });
  next();
});

// Health check - used by Kubernetes liveness/readiness probes
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use('/api/tasks', tasksRouter);

// 404 handler for anything else
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

module.exports = app;