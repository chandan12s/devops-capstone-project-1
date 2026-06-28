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

## Findings (from a real scan, image tag `f812bfc...`)

Scan completed: 2026-06-28. All 15 findings are in a single package -
**`openssl 3.5.6-r0`**, part of the `node:20-alpine` base image's OS
layer, not anything in our own `npm` dependencies. Severity breakdown:
**1 CRITICAL, 8 HIGH, 4 MEDIUM, 2 LOW.**

| Severity | Package | CVE | Summary | Status |
|---|---|---|---|---|
| CRITICAL | openssl 3.5.6-r0 | CVE-2026-34182 | Insufficient validation of cipher/tag fields in CMS `AuthEnvelopedData` processing allows message forgery and integrity bypass | Mitigated - rebuilt with `apk upgrade` (see Dockerfile) |
| HIGH | openssl 3.5.6-r0 | CVE-2026-45447 | Use-after-free during PKCS#7/S-MIME signature verification, can crash or potentially enable code execution | Mitigated - rebuilt with `apk upgrade` |
| HIGH | openssl 3.5.6-r0 | CVE-2026-7383 | Integer overflow sizing a Unicode string buffer in ASN.1 processing, can cause heap buffer overflow | Mitigated - rebuilt with `apk upgrade` |
| HIGH | openssl 3.5.6-r0 | CVE-2026-9076 | Heap out-of-bounds read in CMS password-based key unwrap, can crash the process | Mitigated - rebuilt with `apk upgrade` |
| HIGH | openssl 3.5.6-r0 | CVE-2026-34181 / -34180 / -42764 / -34183 / -45445 | Various DoS / certificate-forgery issues across PKCS#12, ASN.1 decoding, QUIC, and AES-OCB handling - none of these code paths are reachable from our app (we don't terminate QUIC or parse attacker-supplied PKCS#12/CMS), but patched anyway since they ship in the same package update | Mitigated - rebuilt with `apk upgrade` |
| MEDIUM / LOW | openssl 3.5.6-r0 | CVE-2026-42766, -45446, -42767, -42769, -42770, -42768 | Assorted DoS / niche cryptographic edge cases, several requiring attacker-controlled CMP/CMS input our app never processes | Mitigated - rebuilt with `apk upgrade` |

Full raw findings: see the `ecr-scan-findings` workflow artifact.

## Root cause

None of these came from our own code or `npm` dependencies - all 15
were in the OS-level `openssl` package bundled with `node:20-alpine`.
The original Dockerfile only got whatever OpenSSL build was baked into
the base image at the moment that tag was last published; it didn't
explicitly pull current Alpine security updates at build time.

## Fix applied

Added `RUN apk update && apk upgrade --no-cache` to the runtime stage
in `app/Dockerfile`, so every build pulls Alpine's current patched
packages regardless of how old the cached base image layer is. This is
now a standing practice, not a one-time fix - it'll keep picking up
future OS patches automatically on every build.

**If a future rebuild still shows the same CVE:** it likely means
Alpine hasn't published a patched `openssl` build yet (CVE disclosure
and patch availability don't always land same-day). Check
`https://pkgs.alpinelinux.org/packages?name=openssl` for the patched
version, and either wait and retry, or pin explicitly once a fix
exists: `apk add --no-cache 'openssl>=<patched-version>'`.

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
