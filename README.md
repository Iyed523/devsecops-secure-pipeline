# DevSecOps Secure Pipeline

A portfolio project demonstrating how to build a secure CI/CD pipeline around a Python FastAPI application.

The example application, **Release Metadata API**, provides a small, testable foundation for progressively integrating automated quality and security controls.

## Current status

PRs #1 through #6 have been merged into `main`. The project includes a minimal FastAPI health-check endpoint, automated tests, linting and formatting checks, SHA-256-hashed dependency lock files, and security checks using Bandit, pip-audit, Gitleaks, and Semgrep.

GitHub Actions runs the existing quality and security checks on pull requests targeting `main` and on pushes to `main`. The CI run on `main` after PR #6 succeeded.

**PR #7 — Secure Docker Containerization is in progress** on `feature/secure-docker-containerization`. A Dockerfile, a restrictive `.dockerignore`, and a dedicated Docker build and smoke-test job have been prepared. The image was built successfully **locally**, and the container returned `{"status":"ok"}` from `/health` while running as UID/GID `10001:10001` with additional runtime restrictions. **The new Docker CI job has not yet been validated by a GitHub Actions run.**

**Not yet implemented:** container vulnerability scanning, SBOM generation, container registry publishing, and the release evaluation endpoint.

## Technology stack

- Python 3.13
- FastAPI and Uvicorn
- Pytest and HTTPX
- Ruff
- Bandit and pip-audit
- Gitleaks
- Semgrep Community Edition
- pip-tools
- Docker
- GitHub Actions

## Getting started

### Prerequisites

- Python 3.13
- Git
- PowerShell (for the Windows commands below)
- Docker Desktop with Linux containers enabled (for the optional Docker workflow)

### 1. Clone the repository

```powershell
git clone https://github.com/Iyed523/devsecops-secure-pipeline.git
cd devsecops-secure-pipeline
```

### 2. Create and activate a virtual environment

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

The `.venv` directory is excluded from Git.

### 3. Install development dependencies

```powershell
python -m pip install --require-hashes -r requirements-dev.txt
python -m pip check
```

The development requirements include application dependencies as well as testing, code-quality, and Python security-analysis tools. Gitleaks is a separate executable, and Semgrep is installed in a separate virtual environment; neither is installed by `requirements-dev.txt`.

### 4. Run the API locally

```powershell
python -m uvicorn devsecops_demo.main:app --app-dir src --host 127.0.0.1 --port 8000
```

The API is available locally at `http://127.0.0.1:8000`.

## API endpoints

### GET /health

Returns HTTP `200 OK` with the following JSON response:

```json
{
  "status": "ok"
}
```

Test it from a second PowerShell terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health | ConvertTo-Json -Compress
```

The endpoint confirms that the application is responding. It does not perform dependency or infrastructure health checks.

## Secure Docker containerization (PR #7 — in progress)

PR #7 introduces a Docker image for the FastAPI application. The Dockerfile uses the official `python:3.13-slim-bookworm` base image pinned by an OCI index SHA-256 digest, installs only the application dependencies from `requirements.txt` using `--require-hashes`, copies the application source, and runs it with the non-root numeric user `10001:10001`.

The `.dockerignore` uses an allowlist so that only the Dockerfile, `requirements.txt`, and `src/` enter the build context. In particular, Git history, local virtual environments, and other repository files are excluded from that context.

The selected base image is pinned to:

```text
docker.io/library/python:3.13-slim-bookworm@sha256:a1165e272e578941b84abc79e4ab38a0305cd12803a5c4247979ac7655f4d641
```

Pinning a digest prevents unreviewed changes to the base image, but it also means security fixes require an explicit digest update.

### Build the image

Run from the repository root:

```powershell
docker build --platform linux/amd64 --progress=plain -t devsecops-secure-pipeline:pr7 .
```

Inspect the resulting image's platform and configured runtime user:

```powershell
docker image inspect --format '{{.Os}}/{{.Architecture}} User={{.Config.User}}' devsecops-secure-pipeline:pr7
```

Expected configuration:

```text
linux/amd64 User=10001:10001
```

### Run the container with runtime restrictions

```powershell
docker run --detach --rm `
  --name devsecops-pr7-test `
  --publish 127.0.0.1:18000:8000 `
  --read-only `
  --cap-drop=ALL `
  --security-opt=no-new-privileges `
  devsecops-secure-pipeline:pr7
```

The port is published on the host's loopback interface only. `EXPOSE 8000` in the Dockerfile documents the container port; it does not publish the port by itself.

### Verify the application and runtime identity

```powershell
Invoke-RestMethod http://127.0.0.1:18000/health | ConvertTo-Json -Compress
docker exec devsecops-pr7-test id
```

The expected API response and container identity are:

```text
{"status":"ok"}
uid=10001 gid=10001 groups=10001
```

### Stop the test container

```powershell
docker stop devsecops-pr7-test
```

Because the container was started with `--rm`, Docker removes it automatically after stopping it.

### Docker security scope and limitations

- The image uses a pinned base-image digest and hashed application dependencies, but these controls do not prove the image is free from vulnerabilities.
- Dependencies are installed as root **during the image build**; the application process runs as UID/GID `10001:10001` at runtime.
- The read-only filesystem, dropped Linux capabilities, and `no-new-privileges` are **runtime flags** used by the documented `docker run` command and the CI smoke test. They are not enforced automatically by the Dockerfile.
- The initial containerization targets `linux/amd64`. Image vulnerability scanning, SBOM generation, and registry publishing are outside PR #7's scope.

## Tests and code quality

Run the automated tests:

```powershell
python -m pytest -q
```

Check Python code quality:

```powershell
python -m ruff check .
```

Check formatting:

```powershell
python -m ruff format --check .
```

## Security checks

### Python source and dependency scanning

Scan the application source code with Bandit:

```powershell
python -m bandit -r src
```

Audit application dependencies:

```powershell
python -m pip_audit -r requirements.txt
```

Audit development dependencies:

```powershell
python -m pip_audit -r requirements-dev.txt
```

Bandit and pip-audit were validated locally and in GitHub Actions in PR #4. Their checks run on pull requests targeting `main` and on pushes to `main`.

Bandit detects potentially insecure Python patterns, while pip-audit checks for known dependency vulnerabilities. Neither guarantees the absence of security issues. Dependency auditing requires access to vulnerability data sources.

### Semgrep security scanning

Semgrep complements Bandit with project-specific static security analysis rules.

PR #6 integrated Semgrep Community Edition `1.180.0`. Two rules are stored in `.semgrep/python-security.yml`:

- `python-avoid-eval`: detects Python `eval()` calls, which may introduce unsafe dynamic code execution.
- `fastapi-no-debug`: detects `FastAPI(debug=True)`, which should not be enabled in production.

On Windows, install the pinned Semgrep version in a separate virtual environment outside the repository:

```powershell
$semgrepDir = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\semgrep-1.180.0"
python -m venv $semgrepDir
$semgrepPython = Join-Path $semgrepDir "Scripts\python.exe"
& $semgrepPython -m pip install --only-binary=:all: "semgrep==1.180.0"
```

Validate the local rules and scan the application:

```powershell
$semgrepExe = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\semgrep-1.180.0\Scripts\semgrep.exe"
& $semgrepExe scan --metrics=off --validate --config .semgrep/python-security.yml
& $semgrepExe scan --metrics=off --config .semgrep/python-security.yml --error src
```

Local validation confirmed that both rules were valid and the application scan found no violations in two Git-tracked Python files. A separate test with an intentionally insecure temporary file triggered both rules and returned exit code `1`. No insecure test code was committed to Git.

The GitHub Actions workflow installs Semgrep `1.180.0` in a separate virtual environment, validates the rules, and scans `src/` with `--error` to make findings blocking. Metrics are disabled with `--metrics=off`.

PR #6 was merged successfully. Its GitHub Actions run validated both rules and scanned two Git-tracked Python files with zero findings; the CI run on `main` also passed.

The initial rule set is intentionally narrow and is not a comprehensive security audit. Passing the scan does not guarantee the absence of vulnerabilities. Semgrep's version is pinned, but its transitive installation dependencies are not locked with hashes.

### Git history secret scanning

Gitleaks scans Git history for potential secrets, including API keys and access tokens.

PR #5 integrated Gitleaks `8.30.0`. GitHub Actions downloads the Linux x64 archive and verifies its pinned SHA-256 checksum before executing the scanner. The PR #5 CI logs confirmed successful checksum verification and version `8.30.0`.

On Windows, after separately installing and verifying Gitleaks `8.30.0` at the path below, run:

```powershell
$gitleaks = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\gitleaks-8.30.0\gitleaks.exe"
& $gitleaks git --redact=100 --log-opts="--all" --no-banner .
```

The command scans commits reachable through locally available Git references. It does not scan uncommitted working-tree changes. The `--redact=100` option masks detected secret values in the output.

The workflow uses `fetch-depth: 0` to retrieve Git history and runs Gitleaks as a blocking CI step. Gitleaks exits with code `1` when it detects a potential secret and code `0` for a clean scan. In PR #5, GitHub Actions successfully scanned six commits and reported `no leaks found`.

Local validation for PR #5 included a clean Git history scan and a detection test using a fictitious credential passed through standard input. No real credentials or test secrets were committed to the repository.

Gitleaks may produce false positives and cannot detect every exposed secret. Findings require investigation. If a real credential is exposed, revoke or rotate it; removing it from the current files alone is insufficient.

## GitHub Actions CI

The workflow is defined in `.github/workflows/ci.yml` and runs for pull requests targeting `main` and pushes to `main`. Its permissions are restricted to `contents: read`.

The existing `quality` job runs tests, Ruff, Bandit, pip-audit, Gitleaks, and Semgrep. PR #7 adds a separate `container` job that:

1. Builds the Docker image for `linux/amd64`.
2. Starts a container with a read-only filesystem, all Linux capabilities dropped, and privilege escalation disabled.
3. Polls `http://127.0.0.1:18000/health` and checks for `{"status":"ok"}`.
4. Removes the test container at the end of the job.

The Docker job builds and tests an image; it does **not** push to a container registry. Its configuration is present in the PR #7 feature branch, but **its GitHub Actions result is pending**. Local Docker build and runtime checks have already passed.

## Dependency management

The project uses three complementary files:

- `pyproject.toml` declares application and development dependencies.
- `requirements.txt` locks application dependencies.
- `requirements-dev.txt` locks application and development dependencies.

The requirements files are generated with pip-tools and include SHA-256 hashes.

Hashes verify downloaded distributions against recorded fingerprints; they do not establish that dependencies are vulnerability-free.

## Architecture and security

The initial architecture and threat model are documented in:

- [ADR-001 — Initial Architecture](docs/decisions/ADR-001-architecture-initiale.md)
- [Threat Model](docs/threat-model.md)

Bandit and pip-audit provide Python security checks; Gitleaks scans Git history for potential secrets; Semgrep runs two project-specific security rules. PR #7 adds container packaging and a Docker build/smoke-test CI job, with local validation completed and CI validation still pending.

Container vulnerability scanning, SBOM generation, container registry publishing, and the release evaluation endpoint are planned for future project stages.