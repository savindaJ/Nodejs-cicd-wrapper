# Node.js CI/CD Wrapper

A reusable GitHub Action and shell script that runs a full Node.js CI/CD pipeline — clean install, security audit, **SAST static analysis**, lint, test, build, and optional **DAST dynamic scanning** — with retry logic, colored logging, and optional skip flags.

## Pipeline

`setup-build.sh` runs these steps in order:

| Step | Command | Notes |
| --- | --- | --- |
| 1. Environment check | `node -v`, `npm -v` | Fails if Node.js or npm is missing |
| 2. Clean install | `npm ci --include=dev` | Retries up to 3 times with a 10s delay |
| 3. Security audit | `npm audit --audit-level=high` | Fails on high or critical dependency vulnerabilities |
| 4. SAST scan | `semgrep scan` (default, JS/TS/Node/security rules) | Static analysis for security bugs, errors, and coding issues; SARIF + summary report |
| 5. Lint | `npm run lint` | Skipped if no `lint` script exists, or when `--skip-lint` is passed |
| 6. Test | `npm run test` | Skipped if no `test` script exists, or when `--skip-tests` is passed |
| 7. Build | `npm run build` | Always runs |
| 8. Build verification | — | Confirms `build/`, `dist/`, or `.next/` was created |
| 9. DAST scan | OWASP ZAP baseline scan | Runs after build when `dast-target` is set; scans a running application URL |

Required `package.json` scripts:

```json
{
  "scripts": {
    "lint": "eslint .",
    "test": "jest",
    "build": "tsc"
  }
}
```

Lint and test are optional — the script skips them automatically if those scripts are not defined.

## Usage in GitHub Actions

Add the action to any workflow. It sets up Node.js and runs `setup-build.sh` for you:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      security-events: write
    steps:
      - uses: actions/checkout@v4

      - uses: your-org/nodejs-cicd-wrapper@v1
        with:
          node-version: '20'
          skip-tests: 'false'
          skip-lint: 'false'
          skip-sast: 'false'
          sast-fail-on-findings: 'false'
          skip-dast: 'false'
          dast-target: 'http://localhost:3000'
          dast-start-command: 'npm run start'
          dast-fail-on-findings: 'false'
        env:
          NODE_ENV: production
```

### Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `node-version` | Node.js version to install via `actions/setup-node` | No | `20` |
| `skip-tests` | Set to `true` to skip unit tests | No | `false` |
| `skip-lint` | Set to `true` to skip code linting | No | `false` |
| `skip-sast` | Set to `true` to skip SAST static analysis | No | `false` |
| `sast-fail-on-findings` | Set to `true` to fail the job when SAST finds issues | No | `false` |
| `sast-report-dir` | Directory for SAST report files | No | `sast-reports` |
| `skip-dast` | Set to `true` to skip DAST dynamic scanning | No | `false` |
| `dast-target` | Running application URL for OWASP ZAP to scan | No | _(empty — DAST skipped)_ |
| `dast-start-command` | Command to start the app in background before DAST | No | _(empty)_ |
| `dast-start-wait-seconds` | Seconds to wait for the app to become ready | No | `15` |
| `dast-fail-on-findings` | Set to `true` to fail the job when ZAP finds alerts | No | `false` |
| `dast-report-dir` | Directory for DAST report files | No | `dast-reports` |

### SAST static analysis

The wrapper uses [Semgrep](https://semgrep.dev/) for SAST. It scans your source code for:

- Security vulnerabilities (SQL injection, XSS, hardcoded secrets, etc.)
- Programming errors and unsafe patterns
- Coding standard violations
- Syntax and logic issues surfaced by static rules

Reports are published in three places:

1. **GitHub Actions job summary** — severity counts and top findings table
2. **Workflow artifacts** — `semgrep.json`, `semgrep.txt`, and `semgrep.sarif`
3. **GitHub Security tab** — SARIF upload (requires `security-events: write`)

**Fail the pipeline on SAST findings:**

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    sast-fail-on-findings: 'true'
```

**Skip SAST for quick runs:**

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    skip-sast: 'true'
```

### DAST dynamic analysis (OWASP ZAP)

The wrapper uses [OWASP ZAP](https://www.zaproxy.org/) for DAST. It scans a **running application** for runtime vulnerabilities such as:

- Cross-site scripting (XSS)
- Security misconfigurations
- Exposed endpoints and headers
- Injection flaws detectable at runtime

DAST runs **after the build step** when `dast-target` is provided.

**Scan a locally started app (CI):**

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    dast-target: 'http://localhost:3000'
    dast-start-command: 'npm run start'
    dast-start-wait-seconds: '15'
    dast-fail-on-findings: 'false'
```

**Scan a deployed staging URL:**

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    dast-target: 'https://staging.example.com'
    dast-fail-on-findings: 'true'
```

Reports are published in:

1. **GitHub Actions job summary** — alert counts by risk level
2. **Workflow artifacts** — `report_html.html`, `report_json.json`, `report_md.md`

> **Note:** When scanning `localhost`, the wrapper automatically rewrites the URL to the runner IP so OWASP ZAP (running in Docker) can reach your app.

**Skip DAST:**

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    skip-dast: 'true'
```

Or leave `dast-target` empty.

**Server vs frontend DAST — both are supported.** OWASP ZAP scans any running HTTP URL. Point `dast-target` at what you want tested:

| App type | Example `dast-target` | Example `dast-start-command` |
| --- | --- | --- |
| **Backend / API** (Express, NestJS) | `http://localhost:3000` | `npm run start` |
| **Frontend** (React, Next.js, Vite) | `http://localhost:3000` | `npm run start` or `npm run preview` |
| **Deployed staging** | `https://staging.example.com` | _(leave empty — app already running)_ |

ZAP spiders the target URL and checks responses for XSS, missing security headers, misconfigurations, and other runtime issues. It works the same for server-rendered APIs and frontend apps — the difference is only which URL you start and scan.

To scan **both** API and frontend, run the action twice with different `dast-target` values, or scan a deployed environment where both are served under one domain.

**Alert levels and CI failure:**

By default, ZAP fails on any alert including warnings. When `dast-fail-on-findings` is `false`, the wrapper passes `-I` to ZAP so **warnings do not fail the job** — only FAIL-level alerts will fail. Set `dast-fail-on-findings: 'true'` to fail on any alert.

### Examples

**Skip tests on draft pull requests:**

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    node-version: '22'
    skip-tests: ${{ github.event.pull_request.draft == true }}
  env:
    NODE_ENV: test
```

**Use Node.js 22:**

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    node-version: '22'
  env:
    NODE_ENV: production
```

**Run against a monorepo sub-package locally:**

```bash
cd packages/app
NODE_ENV=production ../../setup-build.sh
```

> Replace `your-org/nodejs-cicd-wrapper` with your GitHub org and repository name.

## Local usage

Run the script directly from your project root:

```bash
chmod +x setup-build.sh
NODE_ENV=production ./setup-build.sh
```

### CLI flags

| Flag | Description |
| --- | --- |
| `--skip-tests` | Skip the unit test step |
| `--skip-lint` | Skip the lint step |
| `--skip-sast` | Skip the SAST static analysis step |

```bash
# Full pipeline
NODE_ENV=production ./setup-build.sh

# Skip linting locally for a quick check
NODE_ENV=development ./setup-build.sh --skip-lint

# Install, audit, and build only
NODE_ENV=production ./setup-build.sh --skip-tests --skip-lint
```

### Sample output

```
[INFO] Starting Node.js CI/CD Pipeline Wrapper...
[INFO] Checking required environment variables...
[INFO] Checking Environment Details:
v20.11.0
10.2.4
[INFO] Running 'npm ci' to install clean dependencies...
[SUCCESS] Dependencies installed successfully.
[INFO] Running Security Audit...
[SUCCESS] Security audit passed.
[INFO] Running Code Linting...
[SUCCESS] Linting passed.
[INFO] Running Unit Tests...
[SUCCESS] All tests passed successfully.
[INFO] Building the Node.js application...
[SUCCESS] Build completed and verified successfully.
---------------------------------------------------
[SUCCESS] Pipeline Wrapper Script Executed Successfully!
[INFO] Total Execution Time: 42 seconds.
---------------------------------------------------
```

## Environment variables

The script checks for required environment variables before running. By default it expects:

| Variable | Required | Description |
| --- | --- | --- |
| `NODE_ENV` | Recommended | e.g. `production`, `development`, `test` |

If `NODE_ENV` is not set, a warning is logged. To make it mandatory, change `log_warning` to `log_error` in `setup-build.sh` for that check.

Add more variables to the `REQUIRED_VARS` array in `setup-build.sh` as needed:

```bash
REQUIRED_VARS=("NODE_ENV" "API_URL")
```

## Project structure

```
nodejs-cicd-wrapper/
├── action.yml               # GitHub Action entry point
├── setup-build.sh           # CI/CD pipeline script
├── scripts/
│   ├── sast-summary.sh      # Writes SAST results to GitHub job summary
│   ├── dast-prepare.sh      # Starts app and prepares DAST target URL
│   ├── dast-collect.sh      # Collects OWASP ZAP report files
│   └── dast-summary.sh      # Writes DAST results to GitHub job summary
├── README.md
├── LICENSE
├── .gitignore
└── .github/
    └── workflows/
        └── test-action.yml  # Workflow to test the action
```

## License

MIT — see [LICENSE](LICENSE).
