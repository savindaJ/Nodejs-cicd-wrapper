# Node.js CI/CD Wrapper

A reusable GitHub Action that wraps common Node.js CI/CD steps: dependency install, build, and test.

## Usage

Add this action to any workflow in your repository:

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

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: npm

      - uses: your-org/nodejs-cicd-wrapper@v1
        with:
          node-version: '20'
          package-manager: npm
          working-directory: .
```

## Inputs

| Input | Description | Required | Default |
| --- | --- | --- | --- |
| `node-version` | Node.js version to use | No | `20` |
| `package-manager` | `npm`, `yarn`, or `pnpm` | No | `npm` |
| `install-command` | Custom install command | No | auto-detected |
| `build-command` | Custom build command | No | auto-detected |
| `test-command` | Custom test command | No | auto-detected |
| `working-directory` | Project root inside the repo | No | `.` |
| `skip-build` | Skip the build step | No | `false` |
| `skip-test` | Skip the test step | No | `false` |

## Examples

### Yarn monorepo

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    package-manager: yarn
    working-directory: packages/app
```

### Skip tests on draft PRs

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    skip-test: ${{ github.event.pull_request.draft == true }}
```

### Custom commands

```yaml
- uses: your-org/nodejs-cicd-wrapper@v1
  with:
    install-command: npm ci --legacy-peer-deps
    build-command: npm run build:prod
    test-command: npm run test:ci
```

## Local development

Run the script directly:

```bash
chmod +x setup-build.sh
INPUT_NODE_VERSION=20 INPUT_PACKAGE_MANAGER=npm ./setup-build.sh
```

## License

MIT — see [LICENSE](LICENSE).
