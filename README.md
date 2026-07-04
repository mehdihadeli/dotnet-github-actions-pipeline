# DevSecOps .NET GitHub Actions Sample

**Security-first .NET 10 CI/CD pipeline with staged verification, signed artifacts, SBOM generation, and promotion evidence.**

[![CI](https://github.com/mehdihadeli/dotnet-github-actions-pipeline/actions/workflows/ci.yaml/badge.svg)](https://github.com/mehdihadeli/dotnet-github-actions-pipeline/actions/workflows/ci.yaml)
[![CD](https://github.com/mehdihadeli/dotnet-github-actions-pipeline/actions/workflows/cd.yaml/badge.svg)](https://github.com/mehdihadeli/dotnet-github-actions-pipeline/actions/workflows/cd.yaml)
![.NET 10](https://img.shields.io/badge/.NET-10-512BD4?logo=dotnet)
![Pipeline](https://img.shields.io/badge/pipeline-devsecops-111827)
![SBOM](https://img.shields.io/badge/SBOM-CycloneDX%20%7C%20Syft-0A7EA4)
![Signing](https://img.shields.io/badge/signing-Cosign-3C3C3C)

> Practical DevSecOps sample that keeps implementation visible in source instead of hiding it behind opaque reusable workflows. Repeated workflow glue is extracted into small repo-local composite actions, while core validation, security, signing, and deployment logic stays easy to inspect.

Perfect for: platform engineers, DevOps teams, .NET developers, and security-minded teams building GitHub Actions pipelines with explicit quality and trust boundaries.

## 🎯 Overview

This repository demonstrates a security-first .NET delivery pipeline with real CI/CD concerns wired together end to end:

- **Workflow Design**: Separate CI and CD workflows with stage-oriented job boundaries
- **Quality Gates**: Formatting, warning-as-error builds, analyzers, Dockerfile linting, and secret scanning
- **SAST**: Semgrep, Checkov, CodeQL, and optional Sonar analysis
- **SCA and SBOM**: Trivy, Grype, optional Snyk, CycloneDX app SBOM, and Syft image SBOM
- **Supply Chain Controls**: GHCR publish, keyless Cosign signing, signature verification, and GitHub attestations
- **Promotion Evidence**: Machine-readable CI evidence handed from CI into CD
- **Deployment Verification**: Signed image verification before deploy plus staged ZAP baseline validation

## 🧭 Quick Navigation

- [Documentation Index](docs/index.md)
- [Architecture Overview](docs/architecture.md)
- [CI/CD Pipeline Guide](docs/ci-cd-pipeline.md)
- [Security Configuration](docs/security-config.md)
- [GitHub Secrets and Variables](docs/github-secrets.md)
- [Project Structure](docs/project-structure.md)
- [API Reference](docs/api-reference.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## 🏗️ Architecture

```mermaid
flowchart LR
  Dev[Developer Push or PR] --> CI[CI Workflow]
  CI --> Q[Quality Gates]
  Q --> SAST[SAST and IaC Scans]
  SAST --> BT[Build and Test]
  BT --> APP[App Security and App SBOM]
  APP --> IMG[Image Build and Image Security]
  IMG --> GATE[Central Security Gate]
  GATE --> PUB[Publish Sign Verify Attest]
  PUB --> EVIDENCE[CI Evidence Bundle]
  EVIDENCE --> CD[CD Workflow]
  CD --> VERIFY[Verify Signed Image]
  VERIFY --> DEPLOY[Deploy to Azure Container Apps]
  DEPLOY --> ZAP[ZAP Baseline]
  ZAP --> REPORT[Deployment Evidence]
```

### Pipeline Flow

```text
Developer -> Pull Request or Push -> CI Workflow -> Security Gate -> Signed Image + Evidence -> CD Workflow -> Verify -> Deploy -> DAST -> Deployment Evidence
```

## 🚀 Quick Start

### Prerequisites

- .NET 10 SDK
- Docker Desktop or Docker Engine
- Git
- Access to GitHub Actions if you want to exercise CI/CD remotely
- Azure credentials and environment configuration only if you want to exercise deployment

### 1. Clone and bootstrap

```bash
git clone https://github.com/mehdihadeli/dotnet-github-actions-pipeline.git
cd dotnet-github-actions-pipeline

dotnet tool restore
dotnet husky install
SOLUTION_PATH=DevSecOpsPipelineSample.slnx dotnet tool run husky -- run --name setup-solution-restore
```

### 2. Run local validation

```bash
dotnet test --solution DevSecOpsPipelineSample.slnx
docker build -t devsecops-pipeline-sample .
```

### 3. Run CI and CD

- Push a branch or open a pull request to run CI automatically
- Use `workflow_dispatch` when you want to override `sonar_enabled` or opt into `publish_image`
- Let `cd.yaml` promote only successful CI runs that emitted valid `ci-evidence`

### 4. Optional local security integration

If you want to test BOM upload and vulnerability management locally, use the Dependency-Track stack under `deployments/dependency-track/`.

## 📋 Implementation Phases

### ✅ Phase 1: Developer Validation

- Local tool bootstrap with dotnet tools and Husky
- Fast pre-commit formatting checks
- Pre-push build, test, analyzer, and Gitleaks enforcement

### ✅ Phase 2: Quality Gates

- `dotnet format` validation
- Warning-as-error style build checks
- Explicit Roslyn analyzer execution
- Dockerfile linting and secret detection

### ✅ Phase 3: SAST and IaC Analysis

- Semgrep for fast application and config scanning
- Checkov for GitHub Actions, Dockerfile, and IaC-style misconfiguration coverage
- CodeQL for deeper semantic analysis
- Optional SonarCloud or SonarQube analysis

### ✅ Phase 4: Build, Test, and Coverage

- Release build and test execution
- TRX, Microsoft Testing Platform coverage, Cobertura, HTML, Markdown, and lcov outputs
- Optional Coveralls publishing

### ✅ Phase 5: Application Security and SBOM

- CycloneDX application SBOM generation
- Blocking Trivy app scan
- Advisory Grype scan
- Optional Snyk overlay scan
- Optional Dependency-Track BOM upload

### ✅ Phase 6: Container Build and Image Security

- Immutable image build artifact generation
- Syft image SBOM generation
- Blocking Trivy image scan
- Advisory Grype image scan
- Optional Snyk container overlay

### ✅ Phase 7: Security Gate and Promotion Control

- Central pass or fail evaluation across app and image security stages
- Publish only after security gate success
- CI evidence bundle creation for downstream promotion decisions

### ✅ Phase 8: Supply Chain Trust

- GHCR image publish
- Keyless Cosign signing for SBOMs and images
- Signature verification by digest
- GitHub build provenance attestation

### ✅ Phase 9: Deployment and Runtime Verification

- CI-to-CD promotion through `workflow_run`
- Image signature re-verification before deploy
- Azure Container Apps deployment
- ZAP baseline scan against staged runtime
- Deployment evidence recording

## 🛡️ Security Features

### Vulnerability Scanning

- **Semgrep** for fast SAST coverage
- **Checkov** for workflow, Dockerfile, and IaC-style checks
- **CodeQL** for GitHub-native semantic code scanning
- **Trivy** as the primary blocking app and image scanner
- **Grype** as advisory second-opinion app and image scanning
- **Snyk** as optional managed overlay when `SNYK_TOKEN` is configured

### Supply Chain Hardening

- **CycloneDX** for application SBOM generation
- **Syft** for runtime-oriented image SBOM generation
- **Cosign keyless signing** using GitHub OIDC
- **Digest-based verification** before promotion and before deployment
- **GitHub attestations** for build provenance

### Policy and Audit Controls

```yaml
security-model:
  quality-gates: required
  app-scan-blocking: trivy
  image-scan-blocking: trivy
  advisory-scanners:
    - grype
    - snyk-optional
  signing: cosign-keyless
  promotion-evidence: required
  deploy-time-verification: required
```

### Security Outputs

- SARIF uploads to the GitHub Security tab from Semgrep, Checkov, Trivy, Grype, and optional Snyk
- Separate app and image SBOM artifacts
- Machine-readable CI evidence for CD decisions
- Deployment-time evidence after staged verification and DAST

## 🔧 Configuration

### Required deployment secrets

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

### Optional integration secrets

- `DEPENDENCY_TRACK_URL`
- `DEPENDENCY_TRACK_API_KEY`
- `GITLEAKS_LICENSE`
- `SONAR_PROJECT_KEY`
- `SONAR_ORGANIZATION`
- `SONAR_HOST_URL`
- `SONAR_TOKEN`
- `SNYK_TOKEN`

### Optional repository variable

- `SONAR_CI_ENABLED=false` to disable Sonar by default for CI runs

### Optional manual workflow inputs

- `sonar_enabled` to disable Sonar only for one manual run
- `publish_image` to opt into publish, sign, and attest from a manual CI run

### Azure environment settings

- `AZURE_RESOURCE_GROUP`
- `CONTAINER_APP_NAME`
- `STAGED_API_URL`

For full configuration details, see [docs/github-secrets.md](docs/github-secrets.md) and [docs/security-config.md](docs/security-config.md).

## 📊 Usage Examples

### Local validation

```bash
dotnet tool restore
dotnet husky install
dotnet test --solution DevSecOpsPipelineSample.slnx
docker build -t devsecops-pipeline-sample .
```

### Workflow execution

```text
Push or Pull Request -> run CI automatically
Actions -> CI -> Run workflow -> optional sonar_enabled or publish_image override
Successful CI with evidence -> triggers CD workflow_run path
```

### Dependency-Track integration

```text
App SBOM   -> artifacts/sbom/app/bom.json
Image SBOM -> artifacts/sbom/image/image.cdx.json
Upload     -> .github/actions/upload-dependency-track-bom
```

### Documentation-first exploration

```text
Start with docs/index.md
Then architecture.md for trust boundaries
Then ci-cd-pipeline.md for stage behavior
Then security-config.md for policy and scanner details
```

## 📈 Monitoring and Outputs

### Generated artifacts

- Test results in TRX format
- Coverage outputs in native `.coverage`, Cobertura, HTML, Markdown, and lcov formats
- App and image SBOM artifacts
- SARIF findings for GitHub code scanning
- CI evidence and deployment evidence bundles

### GitHub-facing outputs

- Pull request comments from evidence stages
- Code scanning results in the GitHub Security tab
- Workflow summaries for CI and CD runs
- Attestation and signature verification trail for published images

## 🔍 Troubleshooting

### Tool bootstrap issues

```bash
dotnet tool restore
dotnet husky install
SOLUTION_PATH=DevSecOpsPipelineSample.slnx dotnet tool run husky -- run --name setup-solution-restore
```

### Local test failures

```bash
dotnet test --solution DevSecOpsPipelineSample.slnx
./scripts/run-tests.sh
```

### Docker build failures

```bash
docker build -t devsecops-pipeline-sample .
docker images | grep devsecops-pipeline-sample
```

### CI or CD configuration issues

- Confirm required GitHub secrets and environment variables are configured
- Verify `ci-evidence` was produced by the CI run before expecting CD promotion
- Review [docs/troubleshooting.md](docs/troubleshooting.md) and [docs/github-secrets.md](docs/github-secrets.md)

## 🗂️ Repository Highlights

- `.github/workflows/ci.yaml` for validation, security, publication, signing, attestation, and CI evidence
- `.github/workflows/cd.yaml` for promotion, deploy, staged DAST, and deployment evidence
- `.github/actions/` for repo-local composite actions that centralize repeated workflow glue
- `deployments/dependency-track/` for local BOM ingestion experiments
- `docs/` for architecture, configuration, API, and troubleshooting guidance
- `src/DevSecOpsPipelineSample.Api/` for the sample application surface
- `tests/` for automated test coverage

## 📚 Documentation

- [Documentation Index](docs/index.md)
- [Architecture Overview](docs/architecture.md)
- [CI/CD Pipeline Guide](docs/ci-cd-pipeline.md)
- [Security Configuration](docs/security-config.md)
- [GitHub Secrets and Variables](docs/github-secrets.md)
- [Project Structure](docs/project-structure.md)
- [API Reference](docs/api-reference.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## 📞 Support and Project Links

- [Repository](https://github.com/mehdihadeli/dotnet-github-actions-pipeline)
- [Actions](https://github.com/mehdihadeli/dotnet-github-actions-pipeline/actions)
- [Security](https://github.com/mehdihadeli/dotnet-github-actions-pipeline/security)
- [Issues](https://github.com/mehdihadeli/dotnet-github-actions-pipeline/issues)

## 📈 Project Stats

- **CI/CD Workflows**: 2
- **CI Stages**: 9
- **CD Stages**: 5
- **Documentation Guides**: 8
- **Primary Security Layers**: quality, SAST, app SCA, image SCA, signing, attestation, DAST

This sample focuses on readable pipeline design, explicit security controls, and inspectable workflow behavior rather than minimal demo shortcuts.
