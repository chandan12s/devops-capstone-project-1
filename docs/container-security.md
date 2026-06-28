# Container Image Security

## How scanning works in this project

ECR's basic image scanning (powered by Clair) runs automatically on
every push, because `scan_on_push = true` is set on the repository in
`terraform/ecr.tf`. It's free on every ECR repo - no extra cost, no
separate tool to install.

The pipeline (`build-and-push-image` job in `.github/workflows/pipeline.yml`)
waits for each scan to finish, then **fails the build if any CRITICAL
severity finding is reported**. Findings are also saved as a downloadable
`ecr-scan-findings` artifact on every run, regardless of pass/fail.

## Findings (fill this in from your own real scan)

Run this after a push completes, or just open the artifact / AWS Console:
```bash
aws ecr describe-image-scan-findings \
  --repository-name devops-capstone/task-api \
  --image-id imageTag=<sha> \
  --region ap-south-1
```
Or: AWS Console → ECR → `devops-capstone/task-api` → click the image →
**Scan results** tab.

| Severity | Package | CVE | Description | Status |
|---|---|---|---|---|
| _(e.g. HIGH)_ | _(e.g. libssl3)_ | _(e.g. CVE-2024-xxxx)_ | _(one-line summary)_ | _(Mitigated / Accepted risk / Not exploitable in our context)_ |

(Leave this table empty with a note "no findings at time of scan" if
that's genuinely what you see - `node:20-alpine`'s small package count
means it's common to have zero or very few findings. That's a real,
valid result worth recording too, not something to pad out.)

## Mitigations already in place (regardless of specific findings)

These were deliberate choices in `app/Dockerfile`, made before any scan
ran - the goal is a small attack surface, not just patching after the fact:

- **Alpine base image** (`node:20-alpine`) instead of the full Debian-based
  `node:20` - drastically fewer installed OS packages means drastically
  fewer possible CVEs to begin with.
- **Multi-stage build** - `devDependencies` (eslint, jest, supertest,
  nodemon) never make it into the final image at all, since they're
  only installed in the `deps` build stage.
- **Non-root user** (`appuser`) - even if a vulnerability in the app or
  a dependency were exploited, the process doesn't run as root inside
  the container.
- **No unnecessary packages installed** - we don't `apk add` anything
  beyond what's already in the base image.

## If a real CRITICAL finding ever blocks the pipeline

1. Check whether a newer base image tag fixes it:
   ```bash
   docker pull node:20-alpine
   docker build --no-cache -t task-api:test .
   ```
   Alpine ships frequent security patches; a `docker build` often
   picks up a patched base layer just by re-pulling.
2. If the vulnerability is in an npm dependency rather than the OS
   layer, check `npm-audit-report` from the `dependency-scan` job - the
   fix is usually `npm update <package>` or `npm audit fix`.
3. If neither resolves it and the finding is a false positive or not
   exploitable in our context (e.g., a vulnerable code path we never
   call), document that reasoning in the table above under "Status"
   rather than silently ignoring the gate - the pipeline failing is
   doing its job; the human judgment call of "accept this risk" should
   be visible and recorded, not bypassed quietly.