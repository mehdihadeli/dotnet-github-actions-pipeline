# DevSecOps .NET GitHub Actions Sample

Sample shows repo-local composite actions plus split `ci.yaml` and `cd.yaml` workflows for a .NET backend DevSecOps pipeline.

## Structure

- `.github/actions/setup`: restore SDK, tools, and solution dependencies
- `.github/actions/format`: run `dotnet format` validation
- `.github/actions/style`: run warning-as-error build validation
- `.github/actions/analyzers`: run Roslyn analyzers explicitly
- `.github/actions/build`: build solution in Release mode
- `.github/actions/test`: run tests, TRX, native Microsoft Testing Platform `.coverage`, converted Cobertura output, and optional coverage reporting/Coveralls upload
- `.github/actions/publish`: build and optionally push Docker image
- `.github/actions/upload-dependency-track-bom`: reusable CycloneDX BOM upload action for Dependency-Track
- `.github/workflows/ci.yaml`: CI workflow for quality, SAST, app and image SCA, BOM upload, signing, and attestation
- `.github/workflows/cd.yaml`: CD workflow for deployment, post-deploy verification, and ZAP
- `deployments/dependency-track`: local Dependency-Track + PostgreSQL + Trivy server stack with optional API bootstrap script

## Pipeline stages

- quality-check: format, style, analyzers, Gitleaks secret scan, Dockerfile lint
- iac-checkov: Checkov scans GitHub Actions, Dockerfile, and secrets-style IaC/pipeline config
- sast-semgrep: fast Semgrep SAST gate after quality validation and in parallel with CodeQL
- sast-codeql: deep CodeQL semantic analysis for C# in parallel with Semgrep
- sast-sonar: optional Sonar analysis in parallel with Semgrep and CodeQL when Sonar secrets are configured
- dotnet-build-test: build, test, and use the shared test action to upload Microsoft Testing Platform `.coverage` and Cobertura artifacts plus optional HTML/Markdown/lcov coverage reporting and Coveralls upload after parallel SAST jobs pass
- app-sca-security: CycloneDX app SBOM, blocking Trivy app scan, advisory Grype published-output scan, optional blocking Snyk overlay scan
- image-build: build and export image artifact
- image-sca-security: `anchore/sbom-action` image SBOM, blocking Trivy image scan, advisory `anchore/scan-action` image scan, optional blocking Snyk container overlay scan
- supply chain: optional GHCR publish, keyless Cosign signing, Cosign verification, GitHub provenance attestation, optional Azure Container Apps deploy
- zap-baseline: staged passive DAST baseline scan against deployed API URL

## GitHub Security tab

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

## Dependency-Track BOM uploads

The sample uploads both generated CycloneDX BOMs to Dependency-Track through the reusable action at `.github/actions/upload-dependency-track-bom/action.yml`.

Exact CI call sites:

- `dotnet-app-sca-security -> Upload app SBOM to Dependency-Track`
- `image-sca-security -> Upload image SBOM to Dependency-Track`

Exact payloads:

- app BOM file: `artifacts/sbom/app/bom.json`
- app project name: `${APP_SBOM_PROJECT_NAME}`
- app project version: `${github.sha}`
- image BOM file: `artifacts/sbom/image/image.cdx.json`
- image project name: `${APP_SBOM_PROJECT_NAME}-image`
- image project version: `${github.sha}`

Both uploads are gated only by whether `DEPENDENCY_TRACK_URL` and `DEPENDENCY_TRACK_API_KEY` are configured. If either one is missing, the action logs a skip and CI continues.

For local Dependency-Track experiments, see `deployments/dependency-track/`.

## Local validation

```bash
dotnet test --solution DevSecOpsPipelineSample.slnx
docker build -t devsecops-pipeline-sample .
```

## Local hooks

- Husky.Net is installed as a local dotnet tool and configured under `.husky/`
- `pre-commit` runs fast formatting checks only
- `pre-push` runs Gitleaks in Docker plus analyzers, Release build checks, and tests
- local setup after clone:

```bash
dotnet tool restore
dotnet husky install
```

- local Gitleaks uses `zricethezav/gitleaks:latest` so developers do not need a machine-level binary install
- if Docker is missing or the daemon is stopped, the pre-push hook fails with a targeted message before blocking the push
- local Gitleaks runs on `pre-push` instead of `pre-commit` to keep commit latency low while still blocking secrets before they leave the workstation
- CI keeps Gitleaks enforcement and disables Husky execution with `HUSKY=0`
- CI test stage also generates a downloadable HTML coverage report artifact and publishes a markdown coverage summary to the GitHub job summary

## GitHub secrets

`ci.yaml` publish step expects:

- `GHCR_TOKEN`

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

Cosign keyless signing uses GitHub OIDC and does not require a private signing key secret.

## Azure deploy configuration

CD workflow updates an existing Azure Container App by reading GitHub environment-scoped configuration. Provide:

- environment names such as `dev` and `prod`
- `AZURE_RESOURCE_GROUP`
- `CONTAINER_APP_NAME`
- optional `STAGED_API_URL` override if ZAP should scan a specific public endpoint instead of resolved Container App ingress URL

This sample keeps deployment generic on purpose. It demonstrates reusable workflow shape and local composite action layout without hard-coding project-specific infrastructure.

## Supply chain hardening

- external GitHub Actions are pinned to commit SHAs in workflow and composite actions
- Semgrep runs from pinned container image because legacy `semgrep-action` wrapper is deprecated
- Checkov adds IaC and pipeline misconfiguration coverage for GitHub Actions and Dockerfile surfaces in same sample
- Sonar runs as optional parallel quality and security analysis for teams that already use SonarCloud or SonarQube gates
- Trivy uses official `aquasecurity/trivy-action`
- Grype uses official `anchore/scan-action`
- Snyk uses official `snyk/actions/setup` with CLI-driven scans
- Syft SBOM generation uses official `anchore/sbom-action`
- ReportGenerator generates HTML, markdown, and lcov coverage reports from the Cobertura file emitted by the shared test action
- Coveralls uploads the generated lcov coverage file for external coverage history and PR coverage feedback
- Cosign uses Sigstore keyless signing with GitHub OIDC before deployment trust checks
- ZAP baseline adds staged passive DAST coverage after deployment

## Tooling choices

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
