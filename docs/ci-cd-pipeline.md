# CI/CD Pipeline Guide

This document explains the execution model in `.github/workflows/ci.yaml` and `.github/workflows/cd.yaml`.

## CI workflow

### Triggers

- push to `main`
- push of tags
- pull requests
- manual `workflow_dispatch`

Markdown-only changes are excluded from CI path filters.

### Manual inputs

- `sonar_enabled`: enable or disable Sonar for that run
- `publish_image`: opt into image publish/sign/attest from manual CI runs

## CI stages

### Stage 1: Quality Gates

Job: `quality-check`

Purpose:

- validate formatting
- enforce warning-clean style rules
- run analyzers
- detect secrets with Gitleaks
- lint the Dockerfile with Hadolint

### Stage 2: SAST and pipeline scanning

Jobs:

- `sast-semgrep`
- `sast-iac-checkov`
- `sast-codeql`
- `sast-sonar`

Purpose:

- source-code pattern scanning with Semgrep
- GitHub Actions, Dockerfile, and secrets-style checks with Checkov
- optional Snyk IaC overlay and monitor
- deep code analysis with CodeQL
- optional Sonar analysis with its own restore, build, test, and coverage import flow

### Stage 3: Build and test validation

Job: `dotnet-build-test`

Purpose:

- build the solution
- run tests
- produce TRX, native `.coverage`, Cobertura, HTML, Markdown, and lcov outputs
- optionally publish coverage to Coveralls

### Stage 4: Application SCA and SBOM security

Job: `dotnet-app-sca-security`

Purpose:

- generate app SBOM
- sign and verify the SBOM bundle
- run Trivy and Grype against the application surface
- run optional Snyk application scan and monitor
- upload app BOM to Dependency-Track when configured

### Stage 5: Build image artifact

Job: `image-build`

Purpose:

- resolve version metadata
- build the container image once
- export an immutable image artifact for later stages

### Stage 6: Image SCA and SBOM security

Job: `image-sca-security`

Purpose:

- restore the image artifact
- generate image SBOM
- sign and verify the image SBOM bundle
- run Trivy and Grype against the image
- run optional Snyk container scan and monitor
- upload image BOM to Dependency-Track when configured

### Stage 7: Security gate

Job: `security-gate`

Purpose:

- centralize pass or fail enforcement across Sonar, app security, and image security jobs

### Stage 8: Publish, sign, verify, attest

Jobs:

- `image-publish`
- `image-sign`
- `verify-image-signature`
- `attest`

Purpose:

- optionally publish to GHCR
- sign the published image by digest
- verify the signature before final evidence is produced
- generate GitHub provenance attestation

### Stage 9: Record and notify

Job: `record-and-notify`

Purpose:

- collect artifacts from earlier stages
- generate machine-readable deployment metadata
- upload the `ci-evidence` bundle
- comment on pull requests

## CD workflow

### Trigger

- `workflow_run` after CI completes

### Stage 1: Deployment intake

Job: `prepare-deployment`

Purpose:

- download the `ci-evidence` artifact from the triggering CI run
- stop immediately when CI failed, evidence is missing, or auto-deploy metadata is incomplete

### Stage 2: Verify image signature

Job: `verify-image-signature`

Purpose:

- verify the GHCR image again at promotion time using the expected CI workflow identity

### Stage 3: Deploy to staged runtime

Job: `deploy`

Purpose:

- validate Azure environment configuration
- update Azure Container Apps with the verified image digest
- resolve the staged URL for downstream DAST

### Stage 4: DAST

Job: `zap-baseline`

Purpose:

- run OWASP ZAP baseline against the staged endpoint

### Stage 5: Record and notify

Job: `record-and-notify`

Purpose:

- persist deployment evidence and final summary output

## Evidence handoff

The CI workflow produces a `ci-evidence` artifact that contains deployment metadata. CD reads that artifact to decide whether promotion is allowed.

Promotion requires:

- successful CI conclusion
- `ci-evidence` artifact present
- `deployment.autoDeploy=true`
- `deployment.targetEnvironment` present
- signed or verified image digest present

## Related documents

- [Architecture Overview](architecture.md)
- [Security Configuration](security-config.md)
- [GitHub Secrets](github-secrets.md)
- [Troubleshooting](troubleshooting.md)
