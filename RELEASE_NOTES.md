# Release Notes — v1.0.0

**Release date:** June 24, 2026  
**Repository:** [savindaJ/Nodejs-cicd-wrapper](https://github.com/savindaJ/Nodejs-cicd-wrapper)  
**Install:** `uses: savindaJ/Nodejs-cicd-wrapper@v1.0.0`

---

## Overview

First stable release of **Node.js CI/CD Wrapper** — a reusable GitHub Composite Action and shell script that runs a full Node.js CI/CD pipeline with retry logic, security auditing, colored logging, and optional skip flags.

Works with any npm-based Node.js project, including **React**, **Next.js**, **NestJS**, **Express** (with a build script), and plain TypeScript/JavaScript apps.

---

## What's included

### GitHub Composite Action (`action.yml`)

Drop-in CI step for GitHub Actions workflows:

```yaml
- uses: actions/checkout@v4

- uses: savindaJ/Nodejs-cicd-wrapper@v1.0.0
  with:
    node-version: '20'
    skip-tests: 'false'
    skip-lint: 'false'
  env:
    NODE_ENV: production
```

### Pipeline script (`setup-build.sh`)

Runs these steps in order:

| Step | Command | Behavior |
| --- | --- | --- |
| 1. Environment check | `node -v`, `npm -v` | Fails if Node.js or npm is missing |
| 2. Clean install | `npm ci --include=dev` | Retries up to 3 times (10s delay) |
| 3. Security audit | `npm audit --audit-level=high` | Fails on high/critical vulnerabilities |
| 4. Lint | `npm run lint` | Auto-skipped if no `lint` script, or with `--skip-lint` |
| 5. Test | `npm run test` | Auto-skipped if no `test` script, or with `--skip-tests` |
| 6. Build | `npm run build` | Always runs |
| 7. Build verification | — | Confirms `build/`, `dist/`, or `.next/` exists |

---

## Highlights

- **Framework-agnostic** — uses standard `package.json` scripts; no framework-specific configuration required
- **Retry logic** — `npm ci` retries automatically on transient network failures
- **Security gate** — blocks builds when high or critical npm audit issues are found
- **Smart skips** — lint and test steps are skipped automatically when scripts are not defined
- **Build verification** — detects silent build failures by checking output directories
- **Local & CI usage** — run the same script locally or inside GitHub Actions
- **Colored logging** — clear `[INFO]`, `[SUCCESS]`, `[WARNING]`, and `[ERROR]` output

---

## Bug fixes

### Dev dependencies now install with `NODE_ENV=production`

**Fixed:** `npm ci` previously skipped `devDependencies` when `NODE_ENV=production`, causing `eslint: not found`, missing test runners, and missing build tools (e.g. TypeScript).

**Change:** Install step now runs `npm ci --include=dev`, so lint, test, and build tools in `devDependencies` are always available during CI — even when `NODE_ENV=production` is set.

---

## Action inputs

| Input | Description | Default |
| --- | --- | --- |
| `node-version` | Node.js version (via `actions/setup-node`) | `20` |
| `skip-tests` | Set to `true` to skip unit tests | `false` |
| `skip-lint` | Set to `true` to skip linting | `false` |

---

## Required project setup

Your consuming project needs:

- `package-lock.json` (required for `npm ci`)
- A `build` script in `package.json` (required)
- Optional `lint` and `test` scripts
- Build output in `build/`, `dist/`, or `.next/`

Example `package.json`:

```json
{
  "scripts": {
    "lint": "eslint .",
    "test": "jest",
    "build": "tsc"
  }
}
```

---

## Local usage

```bash
chmod +x setup-build.sh
NODE_ENV=production ./setup-build.sh
NODE_ENV=production ./setup-build.sh --skip-lint
NODE_ENV=production ./setup-build.sh --skip-tests --skip-lint
```

---

## Known limitations

- **npm only** — `yarn` and `pnpm` are not supported in this release
- **Build output required** — projects without a compile step (e.g. plain Express) must define a `build` script that produces `dist/` or `build/`
- **Monorepos** — run from the package root; no `working-directory` support yet

---

## Commits in this release

- `042b195` — Initial release: composite action, pipeline script, MIT license
- `42f778d` — README: pipeline docs, usage examples, environment variables
- `f19b4a9` — Fix: install devDependencies with `npm ci --include=dev`

---

## Upgrade / migration

No migration needed — this is the first release.

To adopt in an existing workflow, replace manual install/lint/test/build steps with:

```yaml
- uses: savindaJ/Nodejs-cicd-wrapper@v1.0.0
  with:
    node-version: '20'
  env:
    NODE_ENV: production
```

---

## License

MIT — see [LICENSE](LICENSE).
