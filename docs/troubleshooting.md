# Troubleshooting

This document collects the most common failure modes for local validation, CI, and CD.

## Local development issues

### Husky commands fail before build or test

Symptoms:

- local hook fails before `dotnet build` or `dotnet test`
- Husky commands cannot find restored tools or solution state

Checks:

```bash
dotnet tool restore
dotnet husky install
SOLUTION_PATH=DevSecOpsPipelineSample.slnx dotnet tool run husky -- run --name setup-solution-restore
```

### Gitleaks fails locally

Symptoms:

- pre-push hook fails before push
- Docker error appears instead of leak results

Cause:

- local Gitleaks uses Docker image `zricethezav/gitleaks:latest`

Checks:

```bash
docker version
docker ps
```

If Docker Desktop is stopped or unavailable, the hook intentionally fails before push.

### Docker build fails locally

Checks:

```bash
docker build -t devsecops-pipeline-sample .
```

Also verify:

- Docker daemon is running
- repository root is the build context
- the root `Dockerfile` has not been renamed

## CI issues

### Sonar did not run

Checks:

- verify `sonar_enabled` was not set to `false` for a manual run
- verify `SONAR_CI_ENABLED` is not set to `false`
- verify required Sonar secrets are present

### Dependency-Track upload did not run

Checks:

- verify `DEPENDENCY_TRACK_URL` exists
- verify `DEPENDENCY_TRACK_API_KEY` exists

The workflow skips BOM upload when either value is missing.

### Snyk scans did not run

Checks:

- verify `SNYK_TOKEN` is configured

Snyk overlay scans and monitor steps are optional by design.

### Publish stage did not run

Expected behavior:

- publish runs after the security gate passes
- sign, verify, and attest run after publish on every successful CI run
- skipped publish now usually means an upstream dependency failed or was skipped

## CD issues

### Deployment did not start

Checks:

- verify the triggering CI run concluded successfully
- verify the `ci-evidence` artifact exists
- verify evidence contains `autoDeploy=true`
- verify a target environment and signed or verified image digest are present

Expected environment routing:

- merges to `main` should emit `targetEnvironment=dev`
- tags should emit `targetEnvironment=staging`

### Deploy job skipped because of missing config

Checks:

- verify target GitHub environment has `DEPLOY_TARGET`
- for `DEPLOY_TARGET=aca`, verify `AZURE_RESOURCE_GROUP` and `CONTAINER_APP_NAME`
- for `DEPLOY_TARGET=aks` and `AKS_DEPLOY_MODE=direct`, verify `AKS_RESOURCE_GROUP`, `AKS_CLUSTER_NAME`, and `AKS_MANIFESTS_PATH`
- for `DEPLOY_TARGET=aks` and `AKS_DEPLOY_MODE=flux`, verify `AKS_FLUX_GITOPS_REPOSITORY`, `AKS_FLUX_MANIFEST_PATH`, and `AKS_FLUX_IMAGE_REPOSITORY`

### Azure login fails

Checks:

- verify `AZURE_CLIENT_ID`
- verify `AZURE_TENANT_ID`
- verify `AZURE_SUBSCRIPTION_ID`

### ZAP target cannot be resolved

Checks:

- for Azure Container Apps, set `TARGET_API_URL` when automatic Container App FQDN resolution is not sufficient
- for AKS, set `AKS_TARGET_API_URL` or shared `TARGET_API_URL`
- verify the chosen target endpoint is public and resolvable by the ZAP job

### Deploy fails because target URL is unsafe

Cause:

- `TARGET_API_URL` or `AKS_TARGET_API_URL` contains embedded credentials, a signed query string, or a fragment

Why the workflow blocks it:

- CD writes the resolved URL into workflow outputs and smoke evidence
- putting secrets in the URL would expose them in logs or artifacts

Fix:

- use a plain public endpoint such as `https://api.contoso.com`
- do not use URLs like `https://user:password@api.contoso.com`
- do not use signed URLs such as `https://api.contoso.com?token=...`

### Production promotion did not start

Checks:

- verify the original CD run targeted `staging`
- verify staging deploy succeeded
- verify staging smoke, k6, and ZAP all succeeded
- verify the `production` GitHub Environment exists

### Production promotion is waiting

Expected behavior:

- if the GitHub `production` environment has required reviewers, the workflow pauses before `deploy-production`
- approve the environment deployment in GitHub to continue promotion

### Production smoke, k6, or ZAP failed

Checks:

- verify the `production` environment points to production-specific URLs and resources
- verify `TARGET_API_URL` or `AKS_TARGET_API_URL` actually resolves to the production endpoint
- verify `POST_DEPLOY_API_TEST_PATH` exists in production
- verify `K6_P95_MS`, `K6_VUS`, and `K6_DURATION` are realistic for the production environment

### Flux GitOps push fails

Checks:

- verify `AKS_FLUX_GITOPS_REPOSITORY` points to the intended GitOps repository
- verify `AKS_FLUX_GITOPS_BRANCH` exists or defaults correctly to `main`
- verify `AKS_FLUX_MANIFEST_PATH` exists inside the checked-out GitOps repository
- verify `AKS_FLUX_GITOPS_TOKEN` has write access when the GitOps repository is separate from the application repository
- verify the manifest contains an `image:` line that starts with `AKS_FLUX_IMAGE_REPOSITORY`

## Signature and provenance issues

### Image signature verification fails

Checks:

- verify the image was published and signed in CI
- verify the digest passed into CD matches the published image
- verify the workflow identity still matches `.github/workflows/ci.yaml`

## Related documents

- [CI/CD Pipeline Guide](ci-cd-pipeline.md)
- [Security Configuration](security-config.md)
- [GitHub Secrets](github-secrets.md)
