# DevSecOps Secure Pipeline

A portfolio project demonstrating how to build a secure CI/CD pipeline around a Python FastAPI application.

The example application, **Release Metadata API**, provides a small, testable foundation for progressively integrating automated quality, security, and container checks.

## Current status

**PRs #1 through #7 are merged into `main`.** The project includes a FastAPI health-check endpoint, automated tests, Ruff checks, SHA-256-hashed dependency lock files, Bandit, pip-audit, Gitleaks, Semgrep, and secure Docker containerization. The existing GitHub Actions jobs, **Tests and lint** and **Docker build**, passed on `main` after PR #7.

**PR #8 — Docker Image Vulnerability Scanning with Trivy is in progress** on `feature/trivy-image-scanning`. The proposed changes add Trivy `0.75.0` to the Docker CI job, with a full HIGH/CRITICAL vulnerability report and a separate blocking gate for findings with known fixes. The Linux Trivy archive is pinned by version and SHA-256 checksum.

Local validation has succeeded: the rebuilt image starts as UID/GID `10001:10001`, serves `/health`, excludes generated `.egg-info` metadata, and runs without pip in its final filesystem. The initial image had **61 HIGH/CRITICAL detections** (57 Debian and four Python-related). The updated image had **57 Debian detections** (55 HIGH and two CRITICAL) and no Python HIGH/CRITICAL detections. The fixable-vulnerability gate returned exit code `0`.

**The new Trivy steps have not yet been validated in GitHub Actions.** The 57 Debian detections remain visible in the full report; they have not been declared resolved or formally accepted.

**Not yet implemented:** standalone SBOM artifact generation, container registry publishing, and the release evaluation endpoint.

## Technology stack

- Python 3.13
- FastAPI and Uvicorn
- Pytest and HTTPX
- Ruff
- Bandit and pip-audit
- Gitleaks
- Semgrep Community Edition
- Trivy Community Edition
- pip-tools
- Docker
- GitHub Actions

## Getting started

### Prerequisites

- Python 3.13
- Git
- PowerShell (for the Windows commands below)
- Docker Desktop using Linux containers (for Docker builds and scans)

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

The development lock file includes application dependencies and Python testing, quality, and security tools. Gitleaks and Trivy are standalone executables; Semgrep is installed in a separate virtual environment. These three tools are not installed through `requirements-dev.txt`.

### 4. Run the API locally

```powershell
python -m uvicorn devsecops_demo.main:app --app-dir src --host 127.0.0.1 --port 8000
```

The API is available at `http://127.0.0.1:8000`.

## API endpoints

### GET /health

Returns HTTP `200 OK` and:

```json
{
  "status": "ok"
}
```

Test from another PowerShell terminal:

```powershell
Invoke-RestMethod http://127.0.0.1:8000/health | ConvertTo-Json -Compress
```

This endpoint confirms that the application responds; it does not check external dependencies or infrastructure health.

## Secure Docker containerization (PR #7 merged; PR #8 hardening in progress)

The Dockerfile uses the official `python:3.13-slim-bookworm` image pinned to an OCI index digest, installs only the locked application dependencies with `--require-hashes`, copies the FastAPI source, and runs the application as the non-root numeric user `10001:10001`.

Pinned base image:

```text
docker.io/library/python:3.13-slim-bookworm@sha256:a1165e272e578941b84abc79e4ab38a0305cd12803a5c4247979ac7655f4d641
```

The `.dockerignore` file uses an allowlist for `Dockerfile`, `requirements.txt`, and `src/`. PR #8 further excludes generated `*.egg-info` directories inside `src/`; this exclusion has been checked with a rebuilt image. Git history, virtual environments, and unrelated repository files are excluded from the build context.

PR #8 also removes pip from the final container filesystem after dependency installation. The application has been tested successfully without pip. **Uninstalling pip in a single-stage Dockerfile does not remove files from earlier image layers or the inherited base image.**

### Build the image

Run from the repository root:

```powershell
docker build --platform linux/amd64 --progress=plain -t devsecops-secure-pipeline:local .
```

Inspect the resulting image:

```powershell
docker image inspect --format '{{.Os}}/{{.Architecture}} User={{.Config.User}}' devsecops-secure-pipeline:local
```

Expected configuration:

```text
linux/amd64 User=10001:10001
```

### Run with runtime restrictions

```powershell
docker run --detach --rm `
  --name devsecops-local-test `
  --publish 127.0.0.1:18000:8000 `
  --read-only `
  --cap-drop=ALL `
  --security-opt=no-new-privileges `
  devsecops-secure-pipeline:local
```

The port is published only on the host loopback interface. `EXPOSE 8000` documents the port but does not publish it by itself.

### Test and stop the container

```powershell
Invoke-RestMethod http://127.0.0.1:18000/health | ConvertTo-Json -Compress
docker exec devsecops-local-test id
docker stop devsecops-local-test
```

Expected HTTP response: `{"status":"ok"}`. Expected process identity: `uid=10001 gid=10001 groups=10001`.

With `--rm`, Docker removes the container after it stops.

### Docker security limitations

- A pinned digest prevents an upstream tag from changing the base image silently, but security fixes require an explicit digest update.
- SHA-256-hashed Python dependencies ensure downloaded distributions match recorded fingerprints; this does not establish that packages are vulnerability-free.
- Dependencies are installed with build-time root privileges. The application itself runs as UID/GID `10001:10001`.
- `--read-only`, `--cap-drop=ALL`, and `no-new-privileges` are **runtime settings**, not guarantees enforced by the Dockerfile alone. They are used in the documented command and CI smoke test.
- The current build targets `linux/amd64` and is not published to a container registry.

## Docker image vulnerability scanning (PR #8 in progress)

Trivy scans the Docker image for known vulnerabilities in Debian operating-system packages and Python components. PR #8 uses **Trivy Community Edition `0.75.0`**. The CI installation downloads the official Linux AMD64 archive and verifies its pinned SHA-256 hash before execution.

Pinned checksum for `trivy_0.75.0_Linux-64bit.tar.gz`:

```text
c6e65abddb348e25f10549df887045629cf28cc72453cd1c63acb717316b3f3f
```

### Run a local HIGH/CRITICAL report

First build the current image (as shown in the Docker section). On Windows, after installing and verifying Trivy `0.75.0` outside the repository:

```powershell
$trivyExe = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\trivy-0.75.0\trivy.exe"

& $trivyExe image `
  --scanners vuln `
  --severity HIGH,CRITICAL `
  --format table `
  --exit-code 0 `
  devsecops-secure-pipeline:local
```

This report shows HIGH and CRITICAL detections, including those without a known fix. `--exit-code 0` makes vulnerability findings non-blocking for reporting; it does **not** mean that the image is secure. Scanner execution errors still require investigation.

### Run the blocking fixable-vulnerability gate

```powershell
& $trivyExe image `
  --scanners vuln `
  --severity HIGH,CRITICAL `
  --ignore-unfixed `
  --exit-code 1 `
  --format table `
  devsecops-secure-pipeline:local
```

This check fails when Trivy detects a HIGH or CRITICAL vulnerability for which its data reports a known fix. Vulnerabilities without a known fix are filtered from the **gate only**; they remain visible in the complete report. An exit code of `0` is not evidence of zero vulnerabilities.

### Local validation results (October 12, 2026)

| Image | Debian HIGH | Debian CRITICAL | Python HIGH | Total HIGH/CRITICAL |
| --- | ---: | ---: | ---: | ---: |
| Before PR #8 (`:pr7`) | 55 | 2 | 4 | 61 |
| After local PR #8 changes (`:pr8`) | 55 | 2 | 0 | 57 |

The four initial Python detections concerned `msgpack 1.1.2`, `setuptools 70.3.0`, and `urllib3 2.7.0` (two findings). They were associated with the CycloneDX SBOM embedded in pip `26.2.1`, rather than packages separately listed by `pip list`. The three components and their versions were verified in `pip/_vendor/bom.cdx.json`.

PR #8 excludes local `.egg-info` metadata from the Docker build context and uninstalls pip after installing runtime dependencies. The rebuilt image successfully answered `/health` as UID/GID `10001:10001`. The complete Trivy scan then reported **57 Debian findings (55 HIGH and two CRITICAL)** and **zero Python HIGH/CRITICAL findings**. The blocking scan with `--ignore-unfixed` returned exit code `0`.

None of the 57 Debian findings had a `FixedVersion` populated in that local report. The two CRITICAL detections concerned `libsqlite3-0` (`CVE-2025-7458`) and `zlib1g` (`CVE-2023-45853`). Their lack of a recorded fix does **not** make them harmless or establish that mitigations are unnecessary.

### Security scope and residual risks

- The full report is intentionally **non-blocking**; the separate gate is blocking for fixable HIGH/CRITICAL vulnerabilities.
- Debian findings without a reported fix remain visible and require ongoing review, prioritization, and consideration of upstream advisories and mitigations. They have not been declared resolved or formally accepted.
- Removing pip from the final filesystem reduces tools accessible at runtime, but does not prove that its vulnerable components have been removed from all image layers.
- Trivy's vulnerability database and vendor severity classifications evolve. Results may change without changes to application code.
- A successful scan does not prove the absence of vulnerabilities, and a reported CVE does not by itself prove exploitability in this application.
- The Trivy CI steps are configured on the PR #8 feature branch but **have not yet been validated in GitHub Actions**.
- Standalone SBOM artifact generation, registry publication, and a broader image-hardening redesign are outside the scope of PR #8.

## Tests and code quality

Run the automated tests:

```powershell
python -m pytest -q
```

Check Python linting:

```powershell
python -m ruff check .
```

Check formatting:

```powershell
python -m ruff format --check .
```

## Security checks

### Python source and dependency scanning

Scan source code with Bandit:

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

Bandit and pip-audit were integrated in PR #4 and run on pull requests to `main` and pushes to `main`. Bandit detects potentially insecure Python patterns; pip-audit checks dependencies against known vulnerability advisories. Neither guarantees an absence of security issues, and dependency audits depend on vulnerability data availability.

### Semgrep security scanning

Semgrep complements Bandit with project-specific static security rules. PR #6 integrated Semgrep Community Edition `1.180.0` with two rules stored in `.semgrep/python-security.yml`:

- `python-avoid-eval`: detects Python `eval()` calls.
- `fastapi-no-debug`: detects `FastAPI(debug=True)`.

On Windows, install Semgrep in a separate environment outside the repository:

```powershell
$semgrepDir = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\semgrep-1.180.0"
python -m venv $semgrepDir
$semgrepPython = Join-Path $semgrepDir "Scripts\python.exe"
& $semgrepPython -m pip install --only-binary=:all: "semgrep==1.180.0"
```

Validate the rules and scan the source:

```powershell
$semgrepExe = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\semgrep-1.180.0\Scripts\semgrep.exe"
& $semgrepExe scan --metrics=off --validate --config .semgrep/python-security.yml
& $semgrepExe scan --metrics=off --config .semgrep/python-security.yml --error src
```

Local validation confirmed both rules were valid and detected two intentionally introduced insecure patterns in a temporary test file, with exit code `1`. No insecure test code was committed. The PR #6 and post-merge CI checks passed; the source scan reported zero findings in two Git-tracked Python files.

The rule set is intentionally narrow. Semgrep does not guarantee comprehensive security coverage. Its primary version is pinned, but transitive installation dependencies are not locked with hashes.

### Git history secret scanning

Gitleaks scans Git history for potential exposed secrets. PR #5 integrated Gitleaks `8.30.0` in CI using a Linux executable archive verified by SHA-256.

On Windows, after separately installing and verifying Gitleaks at the specified location:

```powershell
$gitleaks = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\gitleaks-8.30.0\gitleaks.exe"
& $gitleaks git --redact=100 --log-opts="--all" --no-banner .
```

The command checks commits reachable from local Git references, not uncommitted working-tree changes. `--redact=100` masks detected secret values. The workflow checks out Git history with `fetch-depth: 0` and runs Gitleaks as a blocking step.

PR #5 passed both a clean-history scan and a detection test with a fictitious credential passed via standard input. No real or test secrets were committed. Gitleaks can produce false positives and cannot detect every secret. Exposed real credentials must be revoked or rotated, even if removed from source files.

## GitHub Actions CI

The workflow is defined in `.github/workflows/ci.yml` and runs on pull requests targeting `main` and on pushes to `main`. The workflow uses `permissions: contents: read`.

The **`quality`** job runs:

- Hash-locked dependency installation and dependency consistency checks
- Ruff linting and formatting checks
- Pytest
- Bandit and pip-audit
- Gitleaks Git-history secret scanning
- Semgrep rule validation and source scanning

The **`container`** job, introduced by PR #7, runs independently:

1. Build the Docker image for `linux/amd64`.
2. Start it with a read-only filesystem, dropped Linux capabilities, and `no-new-privileges`.
3. Poll `http://127.0.0.1:18000/health` and verify the exact response `{"status":"ok"}`.
4. Clean up the temporary container.

**Both jobs passed on `main` after PR #7.**

PR #8 extends the `container` job with Trivy `0.75.0` installation using an archive with verified SHA-256, followed by a full non-blocking HIGH/CRITICAL vulnerability report and a blocking gate for fixable HIGH/CRITICAL findings.

**The Trivy steps are not yet validated on GitHub Actions.** The pipeline does not publish the Docker image or create a standalone SBOM artifact.

## Dependency management

The project uses three complementary files:

- `pyproject.toml` declares application and development dependencies.
- `requirements.txt` locks runtime application dependencies.
- `requirements-dev.txt` locks runtime and development dependencies.

The requirements files are generated using pip-tools and include SHA-256 hashes. Hashes verify the distributions downloaded against recorded fingerprints; they do not guarantee those packages are vulnerability-free.

## Architecture and security

The initial design and threat model are documented in:

- [ADR-001 — Initial Architecture](docs/decisions/ADR-001-architecture-initiale.md)
- [Threat Model](docs/threat-model.md)

The security pipeline combines code analysis (Bandit and Semgrep), Python dependency auditing (pip-audit), Git history secret scanning (Gitleaks), secure Docker packaging, container smoke testing, and—under development in PR #8—image vulnerability analysis with Trivy.

Residual container findings remain under review. Future milestones include standalone SBOM artifact generation, container registry publishing, and the release evaluation endpoint.