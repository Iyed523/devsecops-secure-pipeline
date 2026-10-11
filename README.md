# DevSecOps Secure Pipeline

A portfolio project demonstrating how to build a secure CI/CD pipeline around a Python FastAPI application.

The example application, **Release Metadata API**, provides a small, testable foundation for progressively integrating automated quality and security controls.

## Current status

The application currently exposes a health-check endpoint and includes automated tests, Python linting and formatting checks, and locked dependencies with SHA-256 hashes.

GitHub Actions runs automated tests, code-quality checks, Bandit, and pip-audit on pull requests targeting `main` and on pushes to `main`.

PR #5 adds Gitleaks secret scanning to the existing workflow. The Gitleaks integration has been tested locally; its execution in GitHub Actions still needs to be validated before merging the PR.

**Not yet implemented:** Semgrep, Docker packaging, container scanning, SBOM generation, container registry publishing, and the release evaluation endpoint.

## Technology stack

- Python 3.13
- FastAPI and Uvicorn
- Pytest and HTTPX2
- Ruff
- Bandit and pip-audit
- Gitleaks (integration in progress in PR #5)
- pip-tools
- GitHub Actions

## Getting started

### Prerequisites

- Python 3.13
- Git
- PowerShell (for the Windows commands below)

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

The development requirements include application dependencies as well as testing, code-quality, and Python security-analysis tools. Gitleaks is a separate executable and is not installed by pip.

### 4. Run the API

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

### Git history secret scanning

Gitleaks scans Git history for potential secrets, including API keys and access tokens.

PR #5 uses Gitleaks version `8.30.0`. The GitHub Actions workflow configuration downloads the Linux x64 archive and verifies its pinned SHA-256 checksum before executing the scanner. This CI integration has not yet been validated on GitHub Actions.

On Windows, after separately installing and verifying Gitleaks `8.30.0` at the path below, run:

```powershell
$gitleaks = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\gitleaks-8.30.0\gitleaks.exe"
& $gitleaks git --redact=100 --log-opts="--all" --no-banner .
```

The command scans commits reachable through locally available Git references. It does not scan uncommitted working-tree changes. The `--redact=100` option masks detected secret values in the output.

The workflow is configured with `fetch-depth: 0` to retrieve Git history and to run Gitleaks as a blocking CI step. A detected secret causes the scan to exit with code `1`; a clean scan exits with code `0`. The CI behavior will be verified in PR #5 before merging.

Local validation for PR #5 included a clean Git history scan and a detection test using a fictitious credential passed through standard input. No real credentials or test secrets were committed to the repository.

Gitleaks may produce false positives and cannot detect every exposed secret. Findings require investigation. If a real credential is exposed, revoke or rotate it; removing it from the current files alone is insufficient.

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

Bandit and pip-audit provide the initial Python security checks. Gitleaks secret scanning is being integrated in PR #5. Additional controls, including Semgrep, container scanning, and SBOM generation, are planned for later project stages.
