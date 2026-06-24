# Node.js CI/CD Wrapper

A reusable GitHub Action and shell script that runs a full Node.js CI/CD pipeline — clean install, security audit, lint, test, and build — with retry logic, colored logging, and optional skip flags.

## Pipeline

`setup-build.sh` runs these steps in order:

| Step | Command | Notes |
| --- | --- | --- |
| 1. Environment check | `node -v`, `npm -v` | Fails if Node.js or npm is missing |
| 2. Clean install | `npm ci` | Retries up to 3 times with a 10s delay |
| 3. Security audit | `npm audit --audit-level=high` | Fails on high or critical vulnerabilities |
| 4. Lint | `npm run lint` | Skipped if no `lint` script exists, or when `--skip-lint` is passed |
| 5. Test | `npm run test` | Skipped if no `test` script exists, or when `--skip-tests` is passed |
| 6. Build | `npm run build` | Always runs |
| 7. Build verification | — | Confirms `build/`, `dist/`, or `.next/` was created |

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
    steps:
      - uses: actions/checkout@v4

      - uses: your-org/nodejs-cicd-wrapper@v1
        with:
          node-version: '20'
          skip-tests: 'false'
          skip-lint: 'false'
        env:
          NODE_ENV: production
```

### Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `node-version` | Node.js version to install via `actions/setup-node` | No | `20` |
| `skip-tests` | Set to `true` to skip unit tests | No | `false` |
| `skip-lint` | Set to `true` to skip code linting | No | `false` |

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
├── README.md
├── LICENSE
├── .gitignore
└── .github/
    └── workflows/
        └── test-action.yml  # Workflow to test the action
```

## License

MIT — see [LICENSE](LICENSE).
