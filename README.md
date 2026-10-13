# DevSecOps Secure Pipeline

A portfolio project demonstrating how to build a secure CI/CD pipeline around a Python FastAPI application.

The example application, **Release Metadata API**, provides a small, testable foundation for progressively integrating automated quality, security, and container checks.

## Current status

**PRs #1 through #10 are merged into `main`.** The project includes a FastAPI health-check endpoint, automated tests, Ruff, SHA-256-hashed dependency lock files, Bandit, pip-audit, Gitleaks, Semgrep, secure Docker containerization, Trivy vulnerability scanning, Syft-generated CycloneDX SBOM artifacts, and GHCR publishing support. PR #10 was merged as commit `e1ef45f`.

**PR #11 — Private GHCR Publishing Safeguard is in progress** on `fix/ghcr-private-publishing`. The initial GHCR publication after PR #10 created a **public** package, contrary to the project's **private-only** requirement. The public package was subsequently deleted and the GitHub Actions `CI` workflow was manually disabled to prevent another unintended publication. **No replacement private GHCR package has been created or verified.** Deleting the package cannot undo any downloads that may have occurred while it was public.

The PR #11 branch introduces a fail-closed pre-publication API check for an **existing private** GHCR package. This check is not yet merged and has not been executed with `GITHUB_TOKEN` against a private package. **The CI workflow remains disabled** during corrective work.

**SBOM validation:** Syft `1.54.1` successfully generated a CycloneDX 1.7 report from the local PR #8 image (518 components). The PR #9 GitHub Actions artifact was downloaded and independently parsed (3,342 components). Most of the difference involves file entries (400 locally versus 3,229 in CI); the precise cause has not been established.

The latest local Trivy report identified **57 Debian HIGH/CRITICAL findings (55 HIGH and 2 CRITICAL)**, with no fixed versions recorded in that report. They remain under review. Passing the fixable-vulnerability gate does not mean that the image is vulnerability-free.

**Not yet validated:** private GHCR bootstrap, the PR #11 preflight using `GITHUB_TOKEN`, end-to-end private publication after remediation, and the release evaluation endpoint.

## Technology stack

- Python 3.13, FastAPI, and Uvicorn
- Pytest and HTTPX
- Ruff
- Bandit and pip-audit
- Gitleaks
- Semgrep Community Edition
- Trivy Community Edition
- Syft (CycloneDX SBOM generation and CI artifacts)
- pip-tools, Docker, and GitHub Actions

## Getting started

### Prerequisites

- Python 3.13
- Git
- PowerShell for the Windows commands below
- Docker Desktop configured to use Linux containers for container builds and scans

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

The development lock file includes the application, testing, quality, and Python security dependencies. Gitleaks, Trivy, and Syft are standalone executables; Semgrep is installed in a separate virtual environment. These tools are not installed through `requirements-dev.txt`.

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

## Secure Docker containerization (PRs #7 and #8 merged)

The Dockerfile uses the official `python:3.13-slim-bookworm` image pinned to an OCI image index digest, installs hash-locked runtime dependencies, copies the FastAPI source, and runs the application as numeric UID/GID `10001:10001`.

Pinned base image:

```text
docker.io/library/python:3.13-slim-bookworm@sha256:a1165e272e578941b84abc79e4ab38a0305cd12803a5c4247979ac7655f4d641
```

The `.dockerignore` file uses an allowlist for `Dockerfile`, `requirements.txt`, and `src/`, while excluding generated `*.egg-info` metadata. Git history, virtual environments, and unrelated repository files are excluded from the build context.

After installing dependencies, the Dockerfile uninstalls pip from the final container filesystem. **This does not guarantee removal of pip's contents from inherited or previous image layers.**

### Build the image

Run from the repository root:

```powershell
docker build --platform linux/amd64 --progress=plain -t devsecops-secure-pipeline:local .
```

Inspect the image configuration:

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

Expected health response: `{"status":"ok"}`. Expected identity: `uid=10001 gid=10001 groups=10001`. Docker removes the container after it stops because `--rm` is enabled.

### Docker security limitations

- The pinned digest prevents unexpected base-image changes, but security fixes require an explicit digest update.
- Hashes verify downloaded Python distributions against recorded fingerprints; they do not guarantee the absence of vulnerabilities.
- Dependency installation happens with build-time root privileges; the application runs as UID/GID `10001:10001`.
- `--read-only`, `--cap-drop=ALL`, and `no-new-privileges` are runtime options applied by the documented commands and CI smoke test, not automatically enforced by the Dockerfile.
- The current build targets `linux/amd64`. PR #10 added GHCR publication, but the first package was publicly visible and was deleted. Automatic publishing is temporarily disabled until the private-only safeguards are validated.

## Docker image vulnerability scanning (PR #8 merged)

Trivy Community Edition `0.75.0` scans the Docker image for known vulnerabilities in operating-system and application packages. The CI installation downloads the Linux AMD64 executable archive and verifies its pinned SHA-256 checksum before execution.

Checksum of `trivy_0.75.0_Linux-64bit.tar.gz`:

```text
c6e65abddb348e25f10549df887045629cf28cc72453cd1c63acb717316b3f3f
```

### Run a local HIGH/CRITICAL report

After building `devsecops-secure-pipeline:local` and separately installing and verifying Trivy outside the repository:

```powershell
$trivyExe = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\trivy-0.75.0\trivy.exe"

& $trivyExe image `
  --scanners vuln `
  --severity HIGH,CRITICAL `
  --format table `
  --exit-code 0 `
  devsecops-secure-pipeline:local
```

The complete report includes HIGH and CRITICAL findings whether or not a known fix is available. `--exit-code 0` makes vulnerability findings non-blocking for reporting, not the image secure.

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

This check fails on HIGH/CRITICAL findings for which Trivy reports a known fix. Findings without a known fix are filtered **from the gate only** and remain visible in the complete report. Exit code `0` does not mean zero vulnerabilities.

### Local validation results (October 12, 2026)

| Image | Debian HIGH | Debian CRITICAL | Python HIGH | Total HIGH/CRITICAL |
| --- | ---: | ---: | ---: | ---: |
| Before PR #8 (`:pr7`) | 55 | 2 | 4 | 61 |
| After PR #8 changes (`:pr8`) | 55 | 2 | 0 | 57 |

The four original Python findings concerned `msgpack 1.1.2`, `setuptools 70.3.0`, and `urllib3 2.7.0` (two findings). They were associated with the CycloneDX SBOM embedded in pip `26.2.1`, rather than separately installed application dependencies. The rebuilt PR #8 image excluded generated `.egg-info` metadata and did not contain pip in its final filesystem.

The updated image returned the expected `/health` response as UID/GID `10001:10001`. Its full scan reported 57 Debian findings, including two CRITICAL entries for `libsqlite3-0` (`CVE-2025-7458`) and `zlib1g` (`CVE-2023-45853`). The local blocking gate returned exit code `0`. The 57 findings had no `FixedVersion` populated in that report; this does not establish that they are harmless, unexploitable, or permanently unfixable.

**Both GitHub Actions jobs, including the Trivy steps, passed on PR #8 and on `main` after the merge.**

### Security scope and residual risks

- The full report is non-blocking; the separate gate blocks on fixable HIGH/CRITICAL findings.
- Debian findings without a recorded fix remain subject to upstream advisory review, prioritization, risk assessment, and mitigation where appropriate. They have not been declared resolved or formally accepted.
- Uninstalling pip reduces runtime tooling, but may leave bytes in previous image layers.
- Vulnerability databases, vendor severity ratings, and fix availability change over time.
- A scanner finding does not by itself establish exploitability; a passing scan does not prove the absence of vulnerabilities.

## Software Bill of Materials (SBOM) generation (PR #9 merged)

A **Software Bill of Materials (SBOM)** inventories software and related components present in the container image. PR #9 uses **Syft `1.54.1`** to generate a **CycloneDX JSON** report from the built Docker image. A SBOM improves traceability; it is not a vulnerability remediation or proof of security.

The Windows AMD64 Syft archive was downloaded from the official release and verified against the official checksum file during local preparation. The verified archive SHA-256 was:

```text
8b56e8285e295e0bbed26eeea9b16ed51c493be97ccdf42dae6326c84fe8e19f
```

The CI installation uses the official `syft_1.54.1_linux_amd64.tar.gz` archive, version-pinned and verified before execution against SHA-256:

```text
c069905b391cc4c20a5ba65ad5c10be2a7ba074f8ea6ad203e24d14e303dad47
```

### Generate a SBOM locally (Windows PowerShell)

Build the current image using the Docker command above. After separately installing and verifying Syft `1.54.1` outside the repository:

```powershell
$syftExe = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\syft-1.54.1\syft.exe"
$sbomPath = Join-Path $env:TEMP "devsecops-secure-pipeline.cdx.json"

& $syftExe version
& $syftExe "docker:devsecops-secure-pipeline:local" `
  --output "cyclonedx-json=$sbomPath"

if ($LASTEXITCODE -ne 0) {
    throw "Syft SBOM generation failed."
}
```

The output is saved in the Windows temporary directory, **not in the Git repository**.

### Inspect the CycloneDX JSON report

```powershell
$sbom = Get-Content -LiteralPath $sbomPath -Raw | ConvertFrom-Json

[pscustomobject]@{
    Format     = $sbom.bomFormat
    Version    = $sbom.specVersion
    Components = @($sbom.components).Count
    Image      = $sbom.metadata.component.name
} | Format-List

$sbom.components |
    Group-Object -Property type |
    Select-Object Name, Count |
    Format-Table -AutoSize
```

Check important application and operating-system components:

```powershell
$expectedNames = @("fastapi", "uvicorn", "libsqlite3-0", "zlib1g")

$sbom.components |
    Where-Object { $_.name -in $expectedNames } |
    Select-Object name, version, type |
    Sort-Object name |
    Format-Table -AutoSize
```

### Local validation results (October 13, 2026)

Syft `1.54.1` successfully analyzed the `devsecops-secure-pipeline:pr8` image (image ID beginning `a47eb95de15d`) and produced **CycloneDX 1.7** JSON.

| CycloneDX component type | Count |
| --- | ---: |
| `library` | 112 |
| `application` | 5 |
| `file` | 400 |
| `operating-system` | 1 |
| **Total components** | **518** |

Syft separately reported **117 cataloged packages**, corresponding to the 112 libraries and five applications. It also cataloged 792 executables and file metadata for 400 locations. The local SBOM identified `fastapi 0.143.0`, `uvicorn 0.54.0`, `libsqlite3-0 3.40.1-2+deb12u2`, and `zlib1g 1:1.2.13.dfsg-1`.

These measurements describe the tested `:pr8` image and are **not fixed CI assertions**. Package and component counts can change when the image is updated.

### GitHub Actions integration and artifact

PR #9 integrated three steps after Trivy in the `container` job:

1. **Install Syft:** download and SHA-256-verify the pinned Linux AMD64 executable archive before execution.
2. **Generate and validate CycloneDX SBOM:** inventory `devsecops-secure-pipeline:ci`, check JSON structure and a nonempty component list, verify container metadata, and require the `fastapi` and `uvicorn` components.
3. **Upload CycloneDX SBOM:** publish the result as a workflow artifact using `actions/upload-artifact` pinned to a full commit SHA.

| Property | Value |
| --- | --- |
| Artifact name | `container-sbom-cyclonedx` |
| File | `devsecops-secure-pipeline.cdx.json` |
| Format | CycloneDX JSON |
| Retention | 7 days |
| Trigger | Pull requests targeting `main` and pushes to `main` |
| Workflow permission | `contents: read` |

The artifact is available in the completed run's **Artifacts** section, subject to repository access controls and expiration. The file is not committed to Git.

### CI artifact validation (October 13, 2026)

The PR #9 workflow successfully generated and uploaded the SBOM. The downloaded ZIP archive was extracted, and its JSON was parsed in PowerShell. The report identified the container `devsecops-secure-pipeline` and used **CycloneDX 1.7**.

| CycloneDX component type | Local `:pr8` | CI `:ci` |
| --- | ---: | ---: |
| `library` | 112 | 111 |
| `application` | 5 | 1 |
| `file` | 400 | 3,229 |
| `operating-system` | 1 | 1 |
| **Total** | **518** | **3,342** |

The CI report contains `fastapi 0.143.0`, `uvicorn 0.54.0`, `libsqlite3-0 3.40.1-2+deb12u2`, and `zlib1g 1:1.2.13.dfsg-1`.

Most of the difference in total components comes from entries classified as `file`. The exact reason for the local-versus-CI discrepancy remains unconfirmed and should be investigated when improving SBOM reproducibility. Neither total is used as a fixed CI expectation.

**Status:** PR #9 was merged (`cbf42f3`); both CI jobs passed on `main` after the merge, and the downloadable CycloneDX artifact was validated. SBOM generation remains enabled during PR #10.

### SBOM limitations

- A SBOM is an inventory, not a vulnerability scan, exploitability assessment, or remediation.
- Syft coverage depends on its catalogers, available package metadata, and the scanned image; components may be missed or classified differently.
- The report captures an image at scan time and should be regenerated when the image changes.
- The report may reveal package and version information; review access permissions before sharing artifacts.
- Integrity checks validate downloaded archive bytes against a pinned checksum, but do not replace independent verification of publisher identity or release provenance.

## Secure container image publishing to GHCR (PR #10 merged; PR #11 hardening in progress)

PR #10 introduced image publishing support for **GitHub Container Registry (GHCR)** under:

```text
ghcr.io/iyed523/devsecops-secure-pipeline
```

**Required visibility: Private.** The first publication from `main` created a package observed as **Public** on GitHub. It did not meet this requirement. The package was removed, and the `CI` workflow was manually disabled while a corrective control is developed. The precise reason that package visibility became public has not been independently established; **do not rely on a presumed default visibility**.

The Dockerfile includes `org.opencontainers.image.source="https://github.com/Iyed523/devsecops-secure-pipeline"` to identify its source repository. The pinned base image, hash-locked dependencies, and non-root runtime remain unchanged. Local PR #10 validation confirmed the image builds and includes this OCI label.

### Publication policy

| Event | `quality` / `container` checks | Publishing behavior |
| --- | --- | --- |
| Pull request targeting `main` | Run when CI is enabled | **No publishing** — `publish` is skipped |
| Push to another branch | Workflow does not run | No publishing |
| Push to `main`, prerequisite check fails | Run when CI is enabled | **No publishing** — `publish` depends on both jobs |
| Push to `main`, all prerequisites pass | Run when CI is enabled | Allowed only if the PR #11 private-package preflight also succeeds |

The `publish` job additionally checks that `github.repository` equals `Iyed523/devsecops-secure-pipeline`. **Until the corrective PR is merged, the `main` branch still contains the original publishing logic without the private-package preflight; keep CI disabled.**

### Export, transfer, and verification

For a trusted push to `main`, the `container` job is designed to complete its Docker build, restricted smoke test, Trivy scans, and Syft inventory before the export steps:

1. Save the **same built and scanned image** (`devsecops-secure-pipeline:ci`) using `docker save` to `image.tar`.
2. Generate `image.tar.sha256` and verify the archive using `sha256sum --check`.
3. Upload both files as the `scanned-container-image` GitHub Actions artifact, with **one-day retention** and `compression-level: 0`.

The `publish` job depends on `quality` and `container`, downloads the artifact, checks the recorded SHA-256, and loads the image with `docker load`. It **does not rebuild the Docker image**. The accompanying checksum and archive travel together, so this check is not an independent provenance attestation or a digital signature.

### GHCR authentication, tags, and permissions

The workflow's default permission is `contents: read`. Only the `publish` job requests:

```yaml
permissions:
  contents: read
  packages: write
```

The publishing job authenticates to GHCR with `GITHUB_TOKEN` using `docker login ghcr.io --password-stdin`. No personal access token is stored in the workflow. Published images use a tag tied to the full source commit SHA:

```text
ghcr.io/iyed523/devsecops-secure-pipeline:sha-<full-40-character-git-sha>
```

A tag is mutable; use the GHCR manifest digest (`@sha256:...`) to identify the exact published content. Image signing and provenance attestations are not implemented.

### Private GHCR publishing safeguard (PR #11 in progress)

The PR #11 feature branch adds a blocking **`Require existing private GHCR package`** step immediately before Docker login and pushing.

The step queries the GitHub Packages REST API for container packages with `visibility=private` under the expected account and checks for the exact name `devsecops-secure-pipeline`, the expected owner, and reported private visibility. It exits unsuccessfully if the API request fails, the response is unexpected, or an accessible matching private package is not found.

This check is intended to **fail closed**. It does **not** create a package, change visibility, grant package permissions, or guarantee that visibility cannot change after the check. The API endpoint's accessibility with the job's `GITHUB_TOKEN` **has not yet been validated** against the intended private package; insufficient access may block publishing even if a private package exists. Account/package pagination may also require follow-up if the package cannot be located.

A passing preflight must be supplemented by direct verification of the package's **Private** visibility and its repository/Actions access settings after publication.

### Controlled recovery and first private publication

**Do not re-enable GitHub Actions CI or re-create the package from the current unguarded `main` workflow.** The recovery plan is:

1. Review and merge the PR #11 safeguard while the workflow remains disabled. Validate the YAML and code by an independent review or local checks; automatic CI will not run while disabled.
2. Establish a **new private package** through a separately controlled bootstrap publication, using only authorized credentials and the minimum required permissions. Never commit, log, or share credentials. Before proceeding, verify the resulting package is explicitly marked **Private** in GitHub Packages.
3. Review package access settings and explicitly authorize the source repository's GitHub Actions workflow to write to the private package. Do not assume the OCI source label alone grants the intended access.
4. Test the preflight's actual behavior with `GITHUB_TOKEN` in a controlled workflow environment. Confirm a missing/non-private/inaccessible package fails closed and an authorized private package is recognized.
5. Only after these prerequisites, re-enable CI, verify that the full `quality`, `container`, and `publish` jobs succeed, and confirm the new image tag, registry digest, package visibility, and effective access permissions.

No replacement package has yet been created. These steps are **planned**, not completed.

### Security limitations and incident follow-up

- Removing the public package prevents its continued availability on GHCR but cannot revoke any images already downloaded while it was public.
- No automatic publishing should run while the original workflow is disabled and the corrective guard has not been merged and validated.
- The GitHub Packages API check is a preflight guard, **not** a continuous visibility-enforcement mechanism or a guarantee of confidentiality.
- The image and transfer artifact are not cryptographically signed or independently attested.
- The existing Debian HIGH/CRITICAL vulnerability findings remain under review; successful Trivy/Syft checks do not eliminate them.
- The one-day transfer artifact is temporary, not a durable registry backup.
- GHCR access policies, permissions, API availability, and artifact limits may affect publishing.
- Pull requests must never push images to GHCR; no `latest` tag is produced by this workflow.

## Tests and code quality

Run the automated tests:

```powershell
python -m pytest -q
```

Check linting and formatting:

```powershell
python -m ruff check .
python -m ruff format --check .
```

## Security checks

### Python source and dependency scanning

Scan Python source code with Bandit:

```powershell
python -m bandit -r src
```

Audit application and development dependencies:

```powershell
python -m pip_audit -r requirements.txt
python -m pip_audit -r requirements-dev.txt
```

Bandit and pip-audit were integrated in PR #4. Bandit detects potentially insecure Python patterns, while pip-audit checks dependencies against known vulnerability advisories. Neither guarantees the absence of security issues.

### Semgrep security scanning

PR #6 integrated Semgrep Community Edition `1.180.0` with project-specific rules in `.semgrep/python-security.yml`:

- `python-avoid-eval`: detects Python `eval()` calls.
- `fastapi-no-debug`: detects `FastAPI(debug=True)`.

On Windows, install Semgrep in a separate environment outside the repository:

```powershell
$semgrepDir = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\semgrep-1.180.0"
python -m venv $semgrepDir
$semgrepPython = Join-Path $semgrepDir "Scripts\python.exe"
& $semgrepPython -m pip install --only-binary=:all: "semgrep==1.180.0"
```

Validate rules and scan the source:

```powershell
$semgrepExe = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\semgrep-1.180.0\Scripts\semgrep.exe"
& $semgrepExe scan --metrics=off --validate --config .semgrep/python-security.yml
& $semgrepExe scan --metrics=off --config .semgrep/python-security.yml --error src
```

Local validation confirmed that both rules could detect intentionally introduced insecure patterns in a temporary test file. No insecure test code was committed. PR #6 and its post-merge CI checks passed. This rule set is intentionally narrow; Semgrep cannot guarantee complete vulnerability coverage. Its primary version is pinned, but transitive installation dependencies are not locked with hashes.

### Git history secret scanning

PR #5 integrated Gitleaks `8.30.0`. Its Linux executable archive is SHA-256-verified before installation in CI.

On Windows, after independently installing and verifying Gitleaks:

```powershell
$gitleaks = Join-Path $env:LOCALAPPDATA "DevSecOpsTools\gitleaks-8.30.0\gitleaks.exe"
& $gitleaks git --redact=100 --log-opts="--all" --no-banner .
```

This command scans commits reachable from local Git references, not uncommitted working-tree changes. `--redact=100` masks detected secret values. The workflow checks out the complete history with `fetch-depth: 0` and uses Gitleaks as a blocking check.

PR #5 validated clean-history scanning and detection of a fictitious credential without committing it. Gitleaks may produce false positives and cannot detect every secret. Exposed real credentials must be revoked or rotated even if removed from source files.

## GitHub Actions CI

The workflow is defined in `.github/workflows/ci.yml` and is configured for pull requests targeting `main` and pushes to `main`, with `contents: read` as the default permission. **The workflow has been manually disabled following the public GHCR publication incident. It is not currently running automatically.**

The independent **`quality`** job performs hash-locked dependency installation, dependency consistency checks, Ruff linting and formatting, Pytest, Bandit, pip-audit, Gitleaks history scanning, and Semgrep rule validation and source scanning.

The **`container`** job builds the `linux/amd64` image `devsecops-secure-pipeline:ci`, performs a restricted container smoke test, scans with Trivy, and generates, validates, and uploads a CycloneDX SBOM using Syft. **Both jobs passed on `main` after PR #9 merged** (workflow run #16).

PR #10, merged as `e1ef45f`, added Docker image transfer steps to `container` and a third **`publish`** job dependent on both prerequisite jobs. The PR validation succeeded with publishing skipped. After merging, the first GHCR publication created a publicly visible package, which was subsequently deleted. GHCR private-only publication therefore remains **unresolved**.

**PR #11 status:** on `fix/ghcr-private-publishing`, a blocking check for an existing private GHCR package has been added before Docker authentication and pushing. It has **not** yet been merged or validated with the `GITHUB_TOKEN` in a live workflow. Keep CI disabled until the corrected configuration and the private-package bootstrap/access plan have been reviewed and approved.

## Dependency management

The project uses three complementary files:

- `pyproject.toml` declares application and development dependencies.
- `requirements.txt` locks runtime application dependencies.
- `requirements-dev.txt` locks runtime and development dependencies.

The requirements files are generated with pip-tools and include SHA-256 hashes. Hashes verify downloaded distributions against recorded fingerprints; they do not guarantee that the packages are free from vulnerabilities.

## Architecture and security

The initial design and threat model are documented in:

- [ADR-001 — Initial Architecture](docs/decisions/ADR-001-architecture-initiale.md)
- [Threat Model](docs/threat-model.md)

The pipeline combines source analysis (Bandit and Semgrep), dependency auditing (pip-audit), Git-history secret scanning (Gitleaks), secure Docker packaging, container smoke testing, Trivy vulnerability scanning, and Syft-generated CycloneDX SBOM artifacts. PR #10 introduced GHCR publishing but its first package was public and was removed; PR #11 is hardening the publishing process to enforce the project's **private-only** requirement before resuming automatic publication.

Outstanding security work includes reviewing the 57 locally observed Debian HIGH/CRITICAL findings, deliberately updating the base image and dependencies, investigating local/CI SBOM inventory differences, validating the private GHCR bootstrap and `GITHUB_TOKEN` preflight, and independently verifying registry visibility, access permissions, and image digest after recovery. The release evaluation endpoint remains a future milestone.
