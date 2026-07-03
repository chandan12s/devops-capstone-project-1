Pipeline Debugging: Root Cause Analysis
Incident summary
What failed: `Security - Dependency Scan (npm audit)` job  
When: [paste the GitHub Actions run timestamp here]  
Run URL: [paste the direct link to the failed Actions run here]  
Impact: `build-and-push-image` and all deploy jobs were blocked
because `dependency-scan` is a required predecessor.

Failure logs 
Run npm ci
npm error code EUSAGE
npm error
npm error The `npm ci` command can only install with an existing package-lock.json or
npm error npm-shrinkwrap.json with lockfileVersion >= 1. Run an install with npm@5 or
npm error later to generate a package-lock.json file, then try again.
npm error
npm error Clean install a project
npm error
npm error Usage:
npm error npm ci
npm error
npm error Options:
npm error [--install-strategy <hoisted|nested|shallow|linked>] [--legacy-bundling]
npm error [--global-style] [--omit <dev|optional|peer> [--omit <dev|optional|peer> ...]]
npm error [--include <prod|dev|optional|peer> [--include <prod|dev|optional|peer> ...]]
npm error [--strict-peer-deps] [--foreground-scripts] [--ignore-scripts] [--no-audit]
npm error [--no-bin-links] [--no-fund] [--dry-run]
npm error [-w|--workspace <workspace-name> [-w|--workspace <workspace-name> ...]]
npm error [-ws|--workspaces] [--include-workspace-root] [--install-links]
npm error
npm error aliases: clean-install, ic, install-clean, isntall-clean
npm error
npm error Run "npm help ci" for more info
npm error A complete log of this run can be found in: /home/runner/.npm/_logs/2026-07-03T09_14_51_091Z-debug-0.log
Error: Process completed with exit code 1.


Root cause
Category: Misconfiguration — wrong working directory for one job.
The pipeline defines a global working directory default at the top level:
```yaml
defaults:
  run:
    working-directory: app
```
This ensures all `run:` steps across all jobs execute inside `app/`,
where `package.json` lives. However, the `dependency-scan` job had an
additional job-level `defaults` block added that explicitly overrode
this to `./`:
```yaml
  dependency-scan:
    defaults:
      run:
        working-directory: ./  
```
GitHub Actions applies the most specific scope's default: a job-level
`defaults.run.working-directory` silently overrides the workflow-level
one rather than merging with it. So every `run:` step inside
`dependency-scan` executed from the repo root (`/home/runner/work/...`)
instead of from `app/`. At the root, there is no `package.json`, so
`npm ci` found nothing to install.
The error message (`No such file or directory, open '.../package.json'`)
was the correct symptom but pointed at `package.json` specifically,
which could be misread as a missing file problem rather than a wrong
directory problem. The actual cause was location, not file existence.
Why it wasn't caught before pushing
The job ran syntactically valid YAML — there was no schema error, no
missing key. GitHub Actions accepted the configuration without warning.
The mistake only became visible at runtime when `npm ci` was actually
executed in the wrong directory. This class of bug (valid config, wrong
runtime path) doesn't surface from static linting of the YAML file.

Fix applied
Removed the job-level `defaults` block from `dependency-scan` entirely,
allowing it to inherit the correct `working-directory: app` from the
workflow-level default:
```yaml
  dependency-scan:
    name: Security - Dependency Scan (npm audit)
    needs: build-and-test
    runs-on: ubuntu-latest
    # No job-level defaults block - inherits working-directory: app
```
Validation
After pushing the fix:
`dependency-scan` passed with exit code 0
`build-and-push-image` unblocked and completed successfully
All downstream deploy jobs unblocked