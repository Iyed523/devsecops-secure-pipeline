# DevSecOps Secure Pipeline

A portfolio project demonstrating how to build a secure CI/CD pipeline around a Python FastAPI application.

The example application, **Release Metadata API**, provides a small, testable foundation for progressively integrating automated quality and security controls.

## Current status

The application currently exposes a health-check endpoint and includes automated tests, Python linting and formatting checks, and locked dependencies with SHA-256 hashes.

GitHub Actions runs the existing quality checks on pull requests targeting `main` and on pushes to `main`. This project stage adds Bandit and pip-audit security checks to the same workflow; their CI execution must be validated before merging this change.

**Not yet implemented:** Semgrep, secret scanning, Docker packaging, container scanning, SBOM generation, container registry publishing, and the release evaluation endpoint.

## Technology stack

- Python 3.13
- FastAPI and Uvicorn
- Pytest and HTTPX2
- Ruff
- Bandit and pip-audit
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

The development requirements include the application dependencies as well as testing, code-quality, and security-analysis tools.

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

The GitHub Actions workflow is configured to execute these scans on pull requests targeting `main` and on pushes to `main`. Their first CI run will be verified in the security-scanning pull request.

Bandit checks for potentially insecure Python patterns, while pip-audit checks for known dependency vulnerabilities. Neither tool guarantees the absence of security issues. Dependency auditing requires access to vulnerability data sources.

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

Bandit and pip-audit provide the initial Python security checks. Additional controls, including Semgrep, secret scanning, container scanning, and SBOM generation, are planned for later project stages.
