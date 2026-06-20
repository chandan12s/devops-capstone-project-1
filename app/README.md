# Task API

A simple Express REST API for managing tasks. Built as the application
under test for the DevOps Capstone project (CI/CD, Docker, Kubernetes,
observability, etc. all operate on this app).

## Endpoints

| Method | Path             | Description                          |
|--------|------------------|---------------------------------------|
| GET    | `/health`        | Health check (used by k8s probes)    |
| GET    | `/api/tasks`     | List tasks (optional `?completed=true/false`) |
| POST   | `/api/tasks`     | Create a task (`{ title, description }`) |
| GET    | `/api/tasks/:id` | Get one task                          |
| PUT    | `/api/tasks/:id` | Update a task (`title`, `description`, `completed`) |
| DELETE | `/api/tasks/:id` | Delete a task                         |

## Running locally

```bash
cd app
npm install
npm start          # runs on http://localhost:3000
```

For auto-reload during development:

```bash
npm run dev
```

## Running tests

```bash
npm test
```

This runs the full Jest + Supertest suite (real HTTP requests against the
Express app, not mocked) and prints a coverage report.

## Manual smoke test

```bash
curl http://localhost:3000/health

curl -X POST http://localhost:3000/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Kubernetes"}'

curl http://localhost:3000/api/tasks
```
