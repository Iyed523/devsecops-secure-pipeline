# DevSecOps Secure Pipeline

A portfolio project demonstrating how to build a secure CI/CD pipeline around a Python FastAPI application.

The example application, **Release Metadata API**, provides a small, testable foundation for progressively integrating automated quality and security controls.

## Current status

The application currently exposes a health-check endpoint and includes automated tests, Python linting and formatting checks, and locked dependencies with SHA-256 hashes.

GitHub Actions runs automated tests, Ruff, Bandit, pip-audit, and Gitleaks on pull requests targeting `main` and on pushes to `main`.

PR #6 adds Semgrep security scanning with two version-controlled rules. Local validation and GitHub Actions execution have both succeeded: the CI run validated two rules and scanned two Python files with zero findings. PR #6 is awaiting its final security self-review and merge.

**Not yet implemented:** Docker packaging, container scanning, SBOM generation, container registry publishing, and the release evaluation endpoint.

## Technology stack

- Python 3.13
- FastAPI and Uvicorn
- Pytest and HTTPX2
- Ruff
- Bandit and pip-audit
- Gitleaks
- Semgrep Community Edition
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

The development requirements include application dependencies as well as testing, code-quality, and Python security-analysis tools. Gitleaks is a separate executable, and Semgrep is installed in a separate virtual environment; neither is installed by `requirements-dev.txt`.

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

### Semgrep security scanning

Semgrep complements Bandit with project-specific static security analysis rules.

PR #6 uses Semgrep Community Edition `1.180.0`. Two rules are stored in `.semgrep/python-security.yml`:

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

The PR #6 GitHub Actions run successfully validated both rules and scanned two Git-tracked Python files with zero findings. The scan is limited to files selected by Semgrep and does not guarantee coverage of ignored or untracked files.

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

Bandit and pip-audit provide Python security checks, Gitleaks scans Git history for potential secrets, and PR #6 introduces Semgrep with version-controlled security rules. Docker packaging, container scanning, SBOM generation, and registry publishing remain planned for later project stages.