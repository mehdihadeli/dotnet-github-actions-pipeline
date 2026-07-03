# Security Configuration

This repository layers multiple security controls across source, dependencies, containers, provenance, and staged runtime validation.

## Security coverage map

| Layer                    | Tools                                                       | Notes                                                      |
| ------------------------ | ----------------------------------------------------------- | ---------------------------------------------------------- |
| Code quality and hygiene | `dotnet format`, style build, analyzers, Gitleaks, Hadolint | Runs first for fast feedback                               |
| SAST                     | Semgrep, CodeQL, optional Sonar                             | Checks source patterns, data flow, and quality rules       |
| Pipeline and IaC         | Checkov, optional Snyk IaC                                  | Scans GitHub Actions, Dockerfile, and secrets-style config |
| Application SCA          | Trivy, Grype, optional Snyk                                 | Scans NuGet dependency surface and application artifacts   |
| Image SCA                | Trivy, Grype, optional Snyk                                 | Scans runtime layers and OS packages                       |
| SBOM                     | CycloneDX app SBOM, Syft image SBOM                         | Separate provenance for app graph and image runtime        |
| Signing and provenance   | Cosign, GitHub attestations                                 | Keyless OIDC signing and build provenance                  |
| DAST                     | OWASP ZAP baseline                                          | Post-deploy passive validation                             |

## Blocking versus advisory behavior

Blocking controls in the sample:

- formatting, style, analyzers, Gitleaks, Hadolint
- Semgrep
- Checkov
- Trivy app and image scans
- optional Snyk scans when enabled
- security gate evaluation
- keyless signature verification
- ZAP baseline

Advisory or optional controls:

- Grype acts as a second opinion scanner
- Sonar can be disabled by configuration
- Snyk is an optional managed overlay
- Dependency-Track upload is best-effort and skips when not configured

## SBOM strategy

### Application SBOM

- generated from the .NET project dependency graph
- uploaded from `artifacts/sbom/app/bom.json`
- better fit for NuGet provenance and project-level dependencies

### Image SBOM

- generated from the built container image with Syft-compatible tooling
- uploaded from `artifacts/sbom/image/image.cdx.json`
- better fit for runtime layers and operating system packages

## Versioning rule

The shared version metadata action applies one version rule everywhere:

- tagged build: use the Git tag name
- non-tag build: use the short commit SHA

That rule feeds:

- container image tags
- Dependency-Track project versions
- Snyk `target-reference`
- CI evidence metadata

## GitHub Security tab integration

SARIF outputs from the following scanners are uploaded to GitHub code scanning:

- CodeQL
- Semgrep
- Checkov
- Trivy
- Grype
- optional Snyk scans

## Dependency-Track integration

BOM uploads require:

- `DEPENDENCY_TRACK_URL`
- `DEPENDENCY_TRACK_API_KEY`

If either value is missing, the workflow logs a skip and continues.

## Signing and verification model

### SBOM bundles

- app and image SBOM bundles are signed and verified with Cosign keyless flows

### Published image

- the published image is signed by digest
- CI verifies the image signature before final evidence is written
- CD verifies the signature again before deployment

### Identity model

Verification expects GitHub OIDC certificates issued for this repository and the CI workflow identity.

## Related documents

- [CI/CD Pipeline Guide](ci-cd-pipeline.md)
- [GitHub Secrets](github-secrets.md)
- [Troubleshooting](troubleshooting.md)
