# CI/CD Pipeline Guide

This document explains the execution model in `.github/workflows/ci.yaml` and `.github/workflows/cd.yaml`.

## CI workflow

### Triggers

- push to `main`
- push of tags
- pull requests
- manual `workflow_dispatch`

Markdown-only changes are excluded from CI path filters.

### CI-to-CD environment routing

- `push` to `main` produces CI evidence for `dev`
- `push` of a tag produces CI evidence for `staging`
- pull requests do not auto-deploy
- production is promoted only from the CD workflow after successful staging validation and GitHub Environment approval

### Manual inputs

- `sonar_enabled`: enable or disable Sonar for that run
- `publish_image`: opt into image sign/attest from manual CI runs after publish

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

### Stage 3: Deploy to runtime

Job: `deploy`

Purpose:

- resolve the deploy target from environment configuration
- deploy the verified image to the environment selected by CI evidence
- support Azure Container Apps, AKS directly, or AKS through a Flux-tracked manifest update
- resolve the published deployed URL for downstream smoke, k6, and DAST

Environment mapping:

- `dev` for merges to `main`
- `staging` for tag pushes

Supported deployment modes:

- `DEPLOY_TARGET=aca`: update Azure Container Apps directly with `az containerapp update`
- `DEPLOY_TARGET=aks` and `AKS_DEPLOY_MODE=direct`: use the official `Azure/k8s-deploy` action to apply manifest files with image substitution and rollout checks
- `DEPLOY_TARGET=aks` and `AKS_DEPLOY_MODE=flux`: update a Flux-tracked manifest in a GitOps repository and push it to the configured branch for cluster reconciliation

Published URL resolution:

- ACA uses `TARGET_API_URL` when present, otherwise CD resolves the public Container App FQDN
- AKS uses `AKS_TARGET_API_URL`, or falls back to shared `TARGET_API_URL`

### Stage 4: Post-deploy smoke test

Job: `post-deploy-smoke`

Purpose:

- call the published deployed endpoint after promotion
- verify HTTP 200
- verify JSON content type
- verify basic response shape and minimum item count

### Stage 5: Post-deploy k6

Job: `post-deploy-k6`

Purpose:

- run a short k6 scenario against the published deployed endpoint
- enforce latency and request success thresholds before DAST

### Stage 6: DAST

Job: `zap-baseline`

Purpose:

- run OWASP ZAP baseline against the published deployed endpoint after smoke and k6 pass

### Stage 7: Production promotion

Job: `deploy-production`

Purpose:

- run only when the original CI evidence targeted `staging`
- require successful staging smoke, k6, and ZAP validation first
- pause on the GitHub `production` environment when required reviewers are configured
- deploy the same verified image digest into `production`

### Stage 8: Production smoke test

Job: `post-deploy-smoke-production`

Purpose:

- call the published production endpoint after promotion
- verify HTTP 200, JSON content type, and response shape

### Stage 9: Production k6

Job: `post-deploy-k6-production`

Purpose:

- run a short k6 scenario against the published production endpoint

### Stage 10: Production DAST

Job: `zap-baseline-production`

Purpose:

- run OWASP ZAP baseline against the published production endpoint after production smoke and k6 pass

### Stage 11: Record and notify

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

## CD configuration model

The CD workflow keeps intake, signature verification, post-deploy runtime validation, DAST, promotion gating, and deployment evidence shared across all targets. Only the deploy path changes by configuration.

Target selection:

- `DEPLOY_TARGET=aca|aks`

Promotion behavior:

- `dev` deploys automatically from `main`
- `staging` deploys automatically from tags
- `production` deploys only after successful staging validation and GitHub Environment approval

Post-deploy validation contract:

- `POST_DEPLOY_API_TEST_PATH` optional, defaults to `/weatherforecast`
- `POST_DEPLOY_EXPECTED_MIN_ITEMS` optional, defaults to `1`
- `K6_VUS` optional, defaults to `5`
- `K6_DURATION` optional, defaults to `15s`
- `K6_P95_MS` optional, defaults to `1000`

AKS mode selection:

- `AKS_DEPLOY_MODE=direct|flux`

AKS direct contract:

- provide `AKS_MANIFESTS_PATH`
- `Azure/k8s-deploy` applies the manifest set after `Azure/aks-set-context`
- the verified image digest is injected through the action's `images` input

AKS Flux contract:

- provide `AKS_FLUX_GITOPS_REPOSITORY`, `AKS_FLUX_MANIFEST_PATH`, and `AKS_FLUX_IMAGE_REPOSITORY`
- optionally provide `AKS_FLUX_GITOPS_BRANCH`, defaulting to `main`
- CI updates the GitOps repository, then Flux pulls and reconciles that change from Git

## Deployment examples

### Example: Azure Container Apps

```text
DEPLOY_TARGET=aca
AZURE_RESOURCE_GROUP=rg-devsecops-prod
CONTAINER_APP_NAME=devsecops-api
TARGET_API_URL=https://devsecops-api.contoso.com
```

Behavior:

- CD verifies the signed image digest
- `az containerapp update` points the container app at that verified digest
- CD resolves the published deployed URL from `TARGET_API_URL`, or the live Container App FQDN when the override is omitted
- smoke, k6, and ZAP all target that published deployed URL

### Example: AKS direct

```text
DEPLOY_TARGET=aks
AKS_DEPLOY_MODE=direct
AKS_RESOURCE_GROUP=rg-platform-prod
AKS_CLUSTER_NAME=aks-prod-eus
AKS_NAMESPACE=api
AKS_MANIFESTS_PATH=deploy/aks/base
AKS_TARGET_API_URL=https://api.contoso.com
AKS_ROLLOUT_TIMEOUT=10m
```

Behavior:

- CD authenticates to Azure and sets AKS context
- `Azure/k8s-deploy` applies the manifest path and substitutes the verified image digest
- rollout stability is checked by the action before post-deploy runtime validation runs
- smoke, k6, and ZAP target `AKS_TARGET_API_URL`, or shared `TARGET_API_URL`

Expected filesystem shape for `AKS_MANIFESTS_PATH=deploy/aks/base`:

```text
deploy/
  aks/
    base/
      deployment.yaml
      service.yaml
      ingress.yaml
      kustomization.yaml
```

Example image reference inside the manifest set:

```yaml
containers:
  - name: devsecops-api
    image: ghcr.io/mehdihadeli/devsecops-pipeline-sample:placeholder
```

### Example: AKS plus Flux

```text
DEPLOY_TARGET=aks
AKS_DEPLOY_MODE=flux
AKS_RESOURCE_GROUP=rg-platform-prod
AKS_CLUSTER_NAME=aks-prod-eus
AKS_TARGET_API_URL=https://api.contoso.com
AKS_FLUX_GITOPS_REPOSITORY=contoso/fleet-infra
AKS_FLUX_GITOPS_BRANCH=main
AKS_FLUX_MANIFEST_PATH=clusters/prod/apps/devsecops-api/deployment.yaml
AKS_FLUX_IMAGE_REPOSITORY=ghcr.io/mehdihadeli/devsecops-pipeline-sample
```

Behavior:

- CD verifies the signed image digest
- CD checks out the GitOps repository and rewrites the target manifest image line
- CD commits and pushes to the configured branch
- Flux reconciles that Git change into the cluster
- smoke, k6, and ZAP target `AKS_TARGET_API_URL`, or shared `TARGET_API_URL`

Expected filesystem shape inside `AKS_FLUX_GITOPS_REPOSITORY`:

```text
clusters/
  prod/
    apps/
      devsecops-api/
        deployment.yaml
        service.yaml
        kustomization.yaml
```

Example image reference expected by the rewrite step:

```yaml
containers:
  - name: devsecops-api
    image: ghcr.io/mehdihadeli/devsecops-pipeline-sample:current
```

Matching rule:

- the rewrite step updates the first `image:` line whose value starts with `AKS_FLUX_IMAGE_REPOSITORY`
- if the manifest uses a different repository prefix, the workflow fails fast instead of silently editing the wrong image

Design intent:

- keep one shared promotion and verification flow
- branch only at the deployment boundary
- allow teams to adopt Azure Container Apps first and later switch to official AKS direct deployment or AKS plus Flux without rewriting the rest of CD

## Related documents

- [Architecture Overview](architecture.md)
- [Security Configuration](security-config.md)
- [GitHub Secrets](github-secrets.md)
- [Troubleshooting](troubleshooting.md)
