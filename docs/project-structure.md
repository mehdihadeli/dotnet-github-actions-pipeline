# Project Structure

This document describes the repository layout and the purpose of the main directories.

## Top-level layout

| Path                 | Purpose                                                                |
| -------------------- | ---------------------------------------------------------------------- |
| `.github/actions/`   | Repo-local composite actions used by CI and CD                         |
| `.github/workflows/` | Main CI and CD workflow definitions                                    |
| `.husky/`            | Local developer hooks and Husky-managed helper commands                |
| `src/`               | ASP.NET Core application source                                        |
| `tests/`             | Automated tests                                                        |
| `deployments/`       | Local deployment helpers such as Dependency-Track stack files          |
| `scripts/`           | Convenience scripts for local workflows                                |
| `artifacts/`         | Generated output such as SBOM bundles and scan artifacts               |
| `TestResults/`       | Test result and coverage output produced locally or by validation runs |
| `docs/`              | Project documentation                                                  |

## Application layer

### `src/DevSecOpsPipelineSample.Api`

Contains:

- ASP.NET Core app entry point in `Program.cs`
- controller endpoints under `Controllers/`
- model types such as `WeatherForecast.cs`
- environment-specific configuration in `appsettings*.json`

### `tests/DevSecOpsPipelineSample.UnitTests`

Contains isolated unit tests for controller and model behavior.

### `tests/DevSecOpsPipelineSample.EndToEndTests`

Contains hosted API tests that exercise routing, serialization, and environment-dependent runtime behavior.

### `tests/DevSecOpsPipelineSample.K6Tests`

Contains k6 scripts used by the CD workflow for post-deploy load and response validation.

## Composite action layer

The repository keeps repeated workflow logic local instead of placing everything inline in workflow YAML.

Examples:

- setup and dependency restore
- build and test orchestration
- SARIF upload wrappers
- version metadata resolution
- Cosign installation and signing helpers
- GHCR login and publish helpers
- CI evidence assembly and download

## Workflow layer

### `ci.yaml`

Implements:

- quality gates
- SAST and IaC scanning
- build and test validation
- application and image security scanning
- security gate evaluation
- publish, signing, verification, and attestation
- evidence generation

### `cd.yaml`

Implements:

- CI evidence intake
- deploy-time signature verification
- environment routing for `dev`, `staging`, and manual-gated `production`
- post-deploy smoke and k6 checks
- config-driven deployment to Azure Container Apps, AKS direct, or AKS plus Flux
- ZAP baseline validation
- deployment evidence generation

Typical external paths referenced by `cd.yaml`:

- `AKS_MANIFESTS_PATH`, for example `deploy/aks/base`, points to a manifest directory or file set used by `Azure/k8s-deploy`
- `AKS_FLUX_MANIFEST_PATH`, for example `clusters/prod/apps/devsecops-api/deployment.yaml`, points to a manifest file inside the separate GitOps repository used by Flux mode

## Generated artifacts

Common generated outputs include:

- SARIF files under `artifacts/security/`
- app and image SBOM files under `artifacts/sbom/`
- exported image archive for downstream scan stages
- coverage and TRX files under `TestResults/`
- `ci-evidence` bundle used by CD promotion

## Related documents

- [Architecture Overview](architecture.md)
- [CI/CD Pipeline Guide](ci-cd-pipeline.md)
- [API Reference](api-reference.md)
