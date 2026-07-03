# DevSecOps .NET GitHub Actions Sample

Practical .NET 10 DevSecOps sample that uses repo-local composite actions plus separate CI and CD workflows to enforce code quality, SAST, SCA, SBOM, signing, attestation, deployment, and post-deploy verification.

## Overview

This repository demonstrates how to build a security-first GitHub Actions pipeline for a small .NET API without hiding the implementation behind large reusable workflow layers.

- reusable composite actions for repeated workflow glue
- stage-based CI and CD pipelines with human-readable job labels
- quality gates with format, style, analyzers, and secret scanning
- multi-layer security coverage with Semgrep, Checkov, CodeQL, Sonar, Trivy, Grype, Snyk, SBOM, Cosign, and GitHub attestations
- promotion flow that carries CI evidence into CD before deploy and DAST validation

## Pipeline at a glance

CI flow:

```text
Source -> Quality Gates -> SAST -> Build/Test -> App Security -> Image Build -> Image Security -> Security Gate -> Publish/Sign/Attest -> Evidence
```

CD flow:

```text
CI Evidence -> Verify Signed Image -> Deploy -> ZAP Baseline -> Deployment Evidence
```

## Quick start

### Prerequisites

- .NET 10 SDK
- Docker Desktop or Docker Engine
- Git

### 1. Clone and bootstrap

```bash
dotnet tool restore
dotnet husky install
SOLUTION_PATH=DevSecOpsPipelineSample.slnx dotnet tool run husky -- run --name setup-solution-restore
```

### 2. Run local validation

```bash
dotnet test --solution DevSecOpsPipelineSample.slnx
docker build -t devsecops-pipeline-sample .
```

### 3. Use the pipeline

- push or open a pull request to run CI
- use `workflow_dispatch` when you want to override `sonar_enabled` or `publish_image`
- let `cd.yaml` promote only from successful CI runs that produced valid `ci-evidence`

## Documentation

- [Documentation Index](docs/index.md)
- [Architecture Overview](docs/architecture.md)
- [CI/CD Pipeline Guide](docs/ci-cd-pipeline.md)
- [Security Configuration](docs/security-config.md)
- [GitHub Secrets and Variables](docs/github-secrets.md)
- [Project Structure](docs/project-structure.md)
- [API Reference](docs/api-reference.md)
- [Troubleshooting](docs/troubleshooting.md)

## Repository structure

- `.github/actions/setup`: restore SDK, tools, and solution dependencies
- `.github/actions/format`: run `dotnet format` validation
- `.github/actions/style`: run warning-as-error build validation
- `.github/actions/analyzers`: run Roslyn analyzers explicitly
- `.github/actions/build`: build solution in Release mode
- `.github/actions/test`: run tests, TRX, native Microsoft Testing Platform `.coverage`, converted Cobertura output, and optional coverage reporting/Coveralls upload
- `.github/actions/checkout-code`: shared checkout wrapper with optional fetch-depth control
- `.github/actions/upload-sarif`: shared SARIF upload wrapper for GitHub code scanning
- `.github/actions/resolve-snyk-config`: central Snyk app and image scan enablement logic
- `.github/actions/resolve-snyk-iac-config`: central Snyk IaC enablement logic
- `.github/actions/resolve-snyk-monitor-metadata`: shared Snyk `target-reference` and `project-tags` resolver
- `.github/actions/resolve-version-metadata`: shared build version and image tag resolver; uses tag name for tagged builds, otherwise short SHA
- `.github/actions/setup-cosign`: pinned Cosign installer wrapper
- `.github/actions/sign-keyless-blob`: reusable Cosign blob signing wrapper for SBOM bundles
- `.github/actions/verify-keyless-blob-signature`: reusable Cosign blob verification wrapper for SBOM bundles
- `.github/actions/login-ghcr`: shared GHCR login wrapper
- `.github/actions/sign-published-image`: attach image SBOM and sign published image by digest
- `.github/actions/verify-keyless-image-signature`: verify published image keyless signature by digest
- `.github/actions/create-ci-evidence`: generate CI evidence summary and machine-readable deployment metadata
- `.github/actions/download-ci-evidence-artifacts`: restore the standard CI evidence bundle layout in `record-and-notify`
- `.github/actions/publish`: build and optionally push Docker image
- `.github/actions/upload-dependency-track-bom`: reusable CycloneDX BOM upload action for Dependency-Track
- `.github/workflows/ci.yaml`: CI workflow for quality, SAST, app and image SCA, BOM upload, signing, and attestation
- `.github/workflows/cd.yaml`: CD workflow for deployment, post-deploy verification, and ZAP
- `docs`: project documentation set for architecture, pipeline behavior, security, configuration, API surface, and troubleshooting
- `deployments/dependency-track`: local Dependency-Track + PostgreSQL + Trivy server stack with optional API bootstrap script

## Pipeline stages and job map

CI (`.github/workflows/ci.yaml`):

- Stage 1: Quality Gates
  Job `quality-check`: format, style, analyzers, Gitleaks secret scan, Dockerfile lint
- Stage 2: SAST and Pipeline Misconfiguration Scanning
  Job `sast-semgrep`: fast Semgrep SAST gate after quality validation and in parallel with other SAST jobs
  Job `sast-iac-checkov`: Checkov scans GitHub Actions, Dockerfile, and secrets-style IaC and pipeline config, with optional Snyk IaC overlay and monitor
  Job `sast-codeql`: deep CodeQL semantic analysis for C#
  Job `sast-sonar`: optional Sonar analysis with its own restore, build, test, and coverage-import flow when Sonar is configured
- Stage 3: Build and Test Validation
  Job `dotnet-build-test`: build, test, and use the shared test action to upload Microsoft Testing Platform `.coverage`, Cobertura, HTML, Markdown, lcov coverage outputs, and optional Coveralls data
- Stage 4: Application SCA, SBOM, and Artifact Security
  Job `dotnet-app-sca-security`: publish the application scan surface, sign and verify the CycloneDX app SBOM, run blocking Trivy, advisory Grype, optional blocking Snyk overlay, and upload the BOM to Dependency-Track
- Stage 5: Container Build Preparation
  Job `image-build`: resolve shared version metadata, build the image once, and export the immutable image artifact for downstream stages
- Stage 6: Image SCA, SBOM, and Container Security
  Job `image-sca-security`: restore the image artifact, generate and verify the image SBOM, run blocking Trivy plus advisory Grype, run optional blocking Snyk container overlay, and upload the image BOM to Dependency-Track
- Stage 7: Security Gate Enforcement
  Job `security-gate`: central pass and fail enforcement across Sonar, app security, and image security
- Stage 8: Publish, Sign, Verify, and Attest
  Job `image-publish`: optional GHCR publish on `main`, tags, or manual dispatch with `publish_image=true`
  Job `image-sign`: attach the image SBOM and sign the published image by digest with GitHub OIDC
  Job `verify-image-signature`: verify the published image keyless signature before promotion evidence is finalized
  Job `attest`: publish GitHub build provenance attestation for the signed image
- Stage 9: Evidence, Reporting, and Pull Request Feedback
  Job `record-and-notify`: collect CI evidence artifacts, build summary metadata, upload a `ci-evidence` bundle, and comment on pull requests

CD (`.github/workflows/cd.yaml`):

- Stage 1: Deployment Intake from CI Evidence
  Job `prepare-deployment`: download `ci-evidence`, inspect machine-readable deployment metadata, and decide whether promotion is allowed
- Stage 2: Pre-Deploy Supply Chain Verification
  Job `verify-image-signature`: re-verify the CI-signed image at promotion time
- Stage 3: Deploy to Staged Runtime
  Job `deploy`: log in to Azure and update Azure Container Apps with the verified image digest
- Stage 4: DAST on Staged API
  Job `zap-baseline`: run staged passive DAST against the resolved staged endpoint
- Stage 5: Deployment Evidence and Summary
  Job `record-and-notify`: persist deployment evidence and summary output for the promotion run

## Security outputs and integrations

### GitHub Security tab

- CodeQL results upload directly to GitHub Security tab
- Semgrep SARIF uploads to GitHub Security tab
- Checkov SARIF uploads to GitHub Security tab
- Trivy app SARIF uploads to GitHub Security tab
- Grype app SARIF uploads to GitHub Security tab
- Snyk app SARIF uploads to GitHub Security tab when `SNYK_TOKEN` is configured
- Trivy image SARIF uploads to GitHub Security tab
- Grype image SARIF uploads to GitHub Security tab
- Snyk image SARIF uploads to GitHub Security tab when `SNYK_TOKEN` is configured
- CodeQL, Semgrep, Trivy, and Grype all surface findings in GitHub code scanning; Semgrep and Trivy remain the blocking CI gates in this sample

### Dependency-Track BOM uploads

The sample uploads both generated CycloneDX BOMs to Dependency-Track through the reusable action at `.github/actions/upload-dependency-track-bom/action.yml`.

Exact CI call sites:

- `dotnet-app-sca-security -> Upload app SBOM to Dependency-Track`
- `image-sca-security -> Upload image SBOM to Dependency-Track`

Exact payloads:

- app BOM file: `artifacts/sbom/app/bom.json`
- app project name: `${APP_SBOM_PROJECT_NAME}`
- app project version: shared build version from `.github/actions/resolve-version-metadata`
- image BOM file: `artifacts/sbom/image/image.cdx.json`
- image project name: `${APP_SBOM_PROJECT_NAME}-image`
- image project version: shared build version from `image-build`

Version rule:

- tagged build: use the Git tag name
- non-tag build: use the short commit SHA

Both uploads are gated only by whether `DEPENDENCY_TRACK_URL` and `DEPENDENCY_TRACK_API_KEY` are configured. If either one is missing, the action logs a skip and CI continues.

For local Dependency-Track experiments, see `deployments/dependency-track/`.

## Developer workflow

### Local hooks and validation

- Husky.Net is installed as a local dotnet tool and configured under `.husky/`
- `pre-commit` runs fast formatting checks only
- `pre-push` runs Gitleaks in Docker plus analyzers, a local Release build that can restore if needed, and tests
- local setup after clone:

```bash
dotnet tool restore
dotnet husky install
SOLUTION_PATH=DevSecOpsPipelineSample.slnx dotnet tool run husky -- run --name setup-solution-restore
```

- local Gitleaks uses `zricethezav/gitleaks:latest` so developers do not need a machine-level binary install
- if Docker is missing or the daemon is stopped, the pre-push hook fails with a targeted message before blocking the push
- local Gitleaks runs on `pre-push` instead of `pre-commit` to keep commit latency low while still blocking secrets before they leave the workstation
- setup bootstrap stays raw: restore tools and install Husky first, then use Husky-managed setup tasks
- Husky `build` is the local variant and allows restore; Husky `build-ci` is the CI-only variant and assumes setup already restored dependencies
- CI keeps Gitleaks enforcement and disables Husky execution with `HUSKY=0`
- CI test stage also generates a downloadable HTML coverage report artifact and publishes a markdown coverage summary to the GitHub job summary

### Local validation commands

```bash
dotnet test --solution DevSecOpsPipelineSample.slnx
docker build -t devsecops-pipeline-sample .
```

## Configuration

### GitHub secrets and workflow inputs

CI image publish/sign flows use the repository-scoped `GITHUB_TOKEN` for GHCR and do not require a separate `GHCR_TOKEN` secret.

`cd.yaml` deployment expects:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Optional integration secrets:

- `DEPENDENCY_TRACK_URL`
- `DEPENDENCY_TRACK_API_KEY`
- `GITLEAKS_LICENSE` if you run this sample in an organization-owned GitHub repository
- `SONAR_PROJECT_KEY` when you enable Sonar analysis
- `SONAR_ORGANIZATION` when you use SonarCloud
- `SONAR_HOST_URL` when you use self-hosted SonarQube; defaults to `https://sonarcloud.io` if omitted
- `SNYK_TOKEN` if you later add managed Snyk overlay scans
- `SONAR_TOKEN` when you enable Sonar analysis

Optional repository variables:

- `SONAR_CI_ENABLED=false` to disable Sonar analysis by default for CI runs; when unset, CI-based Sonar analysis defaults to enabled

Optional manual workflow input:

- `sonar_enabled` for `workflow_dispatch`; defaults to `true` and lets you disable Sonar for a single manually triggered run
- `publish_image` for `workflow_dispatch`; defaults to `false` and lets you opt into publish/sign/attest from a manual CI run

Cosign keyless signing uses GitHub OIDC and does not require a private signing key secret.

### Azure deployment configuration

CD workflow is triggered from a successful CI `workflow_run` and updates an existing Azure Container App by reading GitHub environment-scoped configuration. Provide:

- environment names such as `dev` and `prod`
- `AZURE_RESOURCE_GROUP`
- `CONTAINER_APP_NAME`
- optional `STAGED_API_URL` override if ZAP should scan a specific public endpoint instead of resolved Container App ingress URL

Promotion only proceeds when the CI `ci-evidence` bundle indicates auto-deploy is enabled and includes a signed or verified image digest plus a target environment.

This sample keeps deployment generic on purpose. It demonstrates reusable workflow shape and local composite action layout without hard-coding project-specific infrastructure.

## Design notes

### Supply chain hardening

- external GitHub Actions are pinned to commit SHAs in workflow and composite actions
- Semgrep runs from pinned container image because legacy `semgrep-action` wrapper is deprecated
- Checkov adds IaC and pipeline misconfiguration coverage for GitHub Actions and Dockerfile surfaces in same sample
- Sonar runs as optional parallel quality and security analysis for teams that already use SonarCloud or SonarQube gates
- Trivy uses official `aquasecurity/trivy-action`
- Grype uses official `anchore/scan-action`
- Snyk uses official `snyk/actions/setup` with CLI-driven scans against the restored NuGet `obj/project.assets.json` manifest
- Syft SBOM generation uses official `anchore/sbom-action`
- ReportGenerator generates HTML, markdown, and lcov coverage reports from the Cobertura file emitted by the shared test action
- Coveralls uploads the generated lcov coverage file for external coverage history and PR coverage feedback
- Cosign uses Sigstore keyless signing with GitHub OIDC for app SBOMs, image SBOMs, published images, and deploy-time verification checks
- ZAP baseline adds staged passive DAST coverage after deployment

### Tooling choices

- CodeQL adds deeper semantic analysis and GitHub-native code scanning for C#
- Sonar adds broader quality-gate and hotspot analysis, but does not replace CodeQL or Semgrep in this sample
- Checkov covers workflow and container IaC misconfiguration gaps that SAST and SCA do not cover well
- Semgrep adds fast SAST coverage and fits CI gating well for app code and Dockerfile checks
- Gitleaks adds dedicated secret detection beyond general-purpose filesystem scanners
- Trivy and Grype sit in the SCA layer here, even though Trivy also contributes misconfiguration and secret findings
- Snyk is an optional managed SCA overlay that can add policy controls and a second managed vulnerability data source when `SNYK_TOKEN` is available
- app SBOM: CycloneDX from project graph gives stronger NuGet provenance than image-first tooling
- image SBOM: Syft is better fit for runtime layers and OS packages
- app and image scans: Trivy is blocking primary scanner, Grype adds advisory second opinion and often catches different metadata edges
- Snyk is best treated as optional managed overlay, not required base dependency for portable sample pipeline
- Cosign verification before deploy reduces trust-on-first-use risk for published images
- ZAP baseline is intentionally light-weight passive DAST; deeper authenticated DAST should live in a richer staged environment
