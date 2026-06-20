# Branching Strategy

This project uses a three-tier Git branching model, matching how most
product teams operate a single production service.

## Branches

| Branch       | Purpose                          | Protected? | Deploys to     |
|--------------|-----------------------------------|------------|----------------|
| `main`       | Always reflects production code  | Yes        | Prod env       |
| `develop`    | Integration branch for features  | Yes        | Dev/Test env   |
| `feature/*`  | One branch per feature/fix       | No         | Nowhere (local/PR only) |

## Rules

1. **Nobody commits directly to `main` or `develop`.** All changes go
   through a Pull Request (PR).
2. **Every feature starts from `develop`:**
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/short-description
   ```
3. **A PR is required to merge** `feature/*` → `develop`. At least one
   review (self-review is acceptable for a solo project, but must leave
   actual comments) is required before merging.
4. **`develop` → `main`** is also done via PR, only when `develop` is
   stable and tested. This is effectively a "release."
5. **Branch protection rules** (configured in GitHub → Settings →
   Branches) enforce points 1–4 at the platform level, not just by
   convention.

## Example flow

```
feature/task-api  →  develop  →  main
     (PR #1)          (PR #2, release)
```

## Commit message convention

We use a lightweight Conventional Commits style:

- `feat: add task creation endpoint`
- `fix: return 404 for unknown task id`
- `test: add validation tests for task creation`
- `docs: update branching strategy`
- `chore: add .gitignore`

This makes `git log` readable and could later auto-generate changelogs.
