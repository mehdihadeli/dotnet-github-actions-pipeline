# GitHub Secrets and Variables

This document collects the GitHub configuration expected by the CI and CD workflows.

## Built-in token usage

The sample uses the repository-scoped `GITHUB_TOKEN` for:

- GHCR login and publish
- Gitleaks GitHub integration
- artifact and workflow API access in CD

A separate `GHCR_TOKEN` is not required.

## Required secrets for Azure-backed CD deployment

These secrets are required when the deployment stage needs Azure authentication. That includes Azure Container Apps and direct AKS deployment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Optional integration secrets

### Dependency-Track

- `DEPENDENCY_TRACK_URL`
- `DEPENDENCY_TRACK_API_KEY`

### Sonar

- `SONAR_TOKEN`
- `SONAR_PROJECT_KEY`
- `SONAR_ORGANIZATION`
- `SONAR_HOST_URL`

If `SONAR_HOST_URL` is omitted, the workflow defaults to `https://sonarcloud.io`.

### Snyk

- `SNYK_TOKEN`

### Gitleaks

- `GITLEAKS_LICENSE`

This is only relevant when using the sample in an organization-owned GitHub repository.

### AKS Flux GitOps

- `AKS_FLUX_GITOPS_TOKEN`

This secret is required when `AKS_DEPLOY_MODE=flux` pushes to a separate GitOps repository. If the GitOps repository is the same repository and the default `GITHUB_TOKEN` has sufficient access, this secret can remain unset.

## Repository variables

Optional repository variables:

- `SONAR_CI_ENABLED=false`

When unset, CI-based Sonar analysis defaults to enabled.

## Environment variables for CD environments

The `deploy` job reads environment-scoped variables from the target environment.

Expected GitHub Environments:

- `dev`
- `staging`
- `production`

Recommended routing:

- merges to `main` deploy to `dev`
- tags deploy to `staging`
- `production` uses required reviewers as a manual approval gate

### CD variable matrix

| Variable                         | Scope                | Used for                                  | Required when                                    | Notes                                             |
| -------------------------------- | -------------------- | ----------------------------------------- | ------------------------------------------------ | ------------------------------------------------- |
| `DEPLOY_TARGET`                  | shared               | select ACA or AKS path                    | always                                           | supported values: `aca`, `aks`                    |
| `TARGET_API_URL`                 | shared               | published URL override for smoke, k6, ZAP | optional                                         | ACA can auto-resolve FQDN when unset              |
| `POST_DEPLOY_API_TEST_PATH`      | shared               | smoke and k6 endpoint path                | optional                                         | defaults to `/weatherforecast`                    |
| `POST_DEPLOY_EXPECTED_MIN_ITEMS` | shared               | smoke and k6 response size check          | optional                                         | defaults to `1`                                   |
| `K6_VUS`                         | shared               | k6 load level                             | optional                                         | defaults to `5`                                   |
| `K6_DURATION`                    | shared               | k6 duration                               | optional                                         | defaults to `15s`                                 |
| `K6_P95_MS`                      | shared               | k6 latency threshold                      | optional                                         | defaults to `1000`                                |
| `AZURE_RESOURCE_GROUP`           | environment-specific | ACA resource lookup                       | `DEPLOY_TARGET=aca`                              | per-environment resource group                    |
| `CONTAINER_APP_NAME`             | environment-specific | ACA deployment target                     | `DEPLOY_TARGET=aca`                              | per-environment app name                          |
| `AKS_DEPLOY_MODE`                | shared               | choose direct or Flux AKS flow            | `DEPLOY_TARGET=aks`                              | supported values: `direct`, `flux`                |
| `AKS_RESOURCE_GROUP`             | environment-specific | AKS cluster lookup                        | `DEPLOY_TARGET=aks`                              | per-environment cluster resource group            |
| `AKS_CLUSTER_NAME`               | environment-specific | AKS cluster target                        | `DEPLOY_TARGET=aks`                              | per-environment cluster name                      |
| `AKS_TARGET_API_URL`             | environment-specific | AKS runtime URL for smoke, k6, ZAP        | optional for AKS                                 | falls back to `TARGET_API_URL`                    |
| `AKS_MANIFESTS_PATH`             | shared               | manifest root for direct AKS deploy       | `DEPLOY_TARGET=aks` and `AKS_DEPLOY_MODE=direct` | used by `Azure/k8s-deploy`                        |
| `AKS_NAMESPACE`                  | shared               | direct AKS namespace                      | optional for direct AKS                          | defaults to `default`                             |
| `AKS_ROLLOUT_TIMEOUT`            | shared               | direct AKS rollout timeout                | optional for direct AKS                          | uses action default when unset                    |
| `AKS_FLUX_GITOPS_REPOSITORY`     | shared               | GitOps repo for Flux updates              | `DEPLOY_TARGET=aks` and `AKS_DEPLOY_MODE=flux`   | can be same repo or external repo                 |
| `AKS_FLUX_GITOPS_BRANCH`         | shared               | GitOps branch                             | optional for Flux AKS                            | defaults to `main`                                |
| `AKS_FLUX_MANIFEST_PATH`         | environment-specific | Flux manifest path to rewrite             | `DEPLOY_TARGET=aks` and `AKS_DEPLOY_MODE=flux`   | usually differs by `dev`, `staging`, `production` |
| `AKS_FLUX_IMAGE_REPOSITORY`      | shared               | image prefix to match and rewrite         | `DEPLOY_TARGET=aks` and `AKS_DEPLOY_MODE=flux`   | must match manifest `image:` prefix               |
| `AKS_FLUX_COMMIT_USER_NAME`      | shared               | Flux commit identity                      | optional for Flux AKS                            | defaults to `github-actions[bot]`                 |
| `AKS_FLUX_COMMIT_USER_EMAIL`     | shared               | Flux commit identity email                | optional for Flux AKS                            | defaults to GitHub Actions bot email              |

Use only public credential-free values for `TARGET_API_URL` and `AKS_TARGET_API_URL`.

Runtime target rules:

- ACA uses `TARGET_API_URL` when provided, otherwise CD resolves the Container App FQDN automatically
- AKS uses `AKS_TARGET_API_URL`, or falls back to shared `TARGET_API_URL`
- CD rejects URLs with embedded credentials, query strings, or fragments so tokens do not leak into workflow outputs or test artifacts

## Example environment configurations

Use the same deployment target variables in each environment, but point them at environment-specific resources and URLs.

### Azure Container Apps example

`dev`

```text
DEPLOY_TARGET=aca
AZURE_RESOURCE_GROUP=rg-devsecops-dev
CONTAINER_APP_NAME=devsecops-api-dev
TARGET_API_URL=https://devsecops-api-dev.contoso.com
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=5
K6_DURATION=15s
K6_P95_MS=1000
```

`staging`

```text
DEPLOY_TARGET=aca
AZURE_RESOURCE_GROUP=rg-devsecops-staging
CONTAINER_APP_NAME=devsecops-api-staging
TARGET_API_URL=https://devsecops-api-staging.contoso.com
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=10
K6_DURATION=30s
K6_P95_MS=1200
```

`production`

```text
DEPLOY_TARGET=aca
AZURE_RESOURCE_GROUP=rg-devsecops-prod
CONTAINER_APP_NAME=devsecops-api-prod
TARGET_API_URL=https://devsecops-api.contoso.com
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=15
K6_DURATION=30s
K6_P95_MS=1500
```

Secrets used with this example:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Suggested environment usage:

- `dev`: Container App and URL for development validation
- `staging`: Container App and URL for pre-production validation
- `production`: Container App and URL for approved production promotion

### AKS direct example

`dev`

```text
DEPLOY_TARGET=aks
AKS_DEPLOY_MODE=direct
AKS_RESOURCE_GROUP=rg-platform-dev
AKS_CLUSTER_NAME=aks-dev-eus
AKS_NAMESPACE=api
AKS_MANIFESTS_PATH=deploy/aks/base
AKS_TARGET_API_URL=https://api-dev.contoso.com
AKS_ROLLOUT_TIMEOUT=10m
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=5
K6_DURATION=15s
K6_P95_MS=1000
```

`staging`

```text
DEPLOY_TARGET=aks
AKS_DEPLOY_MODE=direct
AKS_RESOURCE_GROUP=rg-platform-staging
AKS_CLUSTER_NAME=aks-staging-eus
AKS_NAMESPACE=api
AKS_MANIFESTS_PATH=deploy/aks/base
AKS_TARGET_API_URL=https://api-staging.contoso.com
AKS_ROLLOUT_TIMEOUT=10m
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=10
K6_DURATION=30s
K6_P95_MS=1200
```

`production`

```text
DEPLOY_TARGET=aks
AKS_DEPLOY_MODE=direct
AKS_RESOURCE_GROUP=rg-platform-prod
AKS_CLUSTER_NAME=aks-prod-eus
AKS_NAMESPACE=api
AKS_MANIFESTS_PATH=deploy/aks/base
AKS_TARGET_API_URL=https://api.contoso.com
AKS_ROLLOUT_TIMEOUT=10m
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=15
K6_DURATION=30s
K6_P95_MS=1500
```

Secrets used with this example:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

Suggested environment usage:

- `dev`: AKS development cluster and public dev endpoint
- `staging`: AKS staging cluster and staging endpoint
- `production`: AKS production cluster and production endpoint

### AKS Flux example

`dev`

```text
DEPLOY_TARGET=aks
AKS_DEPLOY_MODE=flux
AKS_RESOURCE_GROUP=rg-platform-dev
AKS_CLUSTER_NAME=aks-dev-eus
AKS_TARGET_API_URL=https://api-dev.contoso.com
AKS_FLUX_GITOPS_REPOSITORY=contoso/fleet-infra
AKS_FLUX_GITOPS_BRANCH=main
AKS_FLUX_MANIFEST_PATH=clusters/dev/apps/devsecops-api/deployment.yaml
AKS_FLUX_IMAGE_REPOSITORY=ghcr.io/mehdihadeli/devsecops-pipeline-sample
AKS_FLUX_COMMIT_USER_NAME=github-actions[bot]
AKS_FLUX_COMMIT_USER_EMAIL=41898282+github-actions[bot]@users.noreply.github.com
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=5
K6_DURATION=15s
K6_P95_MS=1000
```

`staging`

```text
DEPLOY_TARGET=aks
AKS_DEPLOY_MODE=flux
AKS_RESOURCE_GROUP=rg-platform-staging
AKS_CLUSTER_NAME=aks-staging-eus
AKS_TARGET_API_URL=https://api-staging.contoso.com
AKS_FLUX_GITOPS_REPOSITORY=contoso/fleet-infra
AKS_FLUX_GITOPS_BRANCH=main
AKS_FLUX_MANIFEST_PATH=clusters/staging/apps/devsecops-api/deployment.yaml
AKS_FLUX_IMAGE_REPOSITORY=ghcr.io/mehdihadeli/devsecops-pipeline-sample
AKS_FLUX_COMMIT_USER_NAME=github-actions[bot]
AKS_FLUX_COMMIT_USER_EMAIL=41898282+github-actions[bot]@users.noreply.github.com
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=10
K6_DURATION=30s
K6_P95_MS=1200
```

`production`

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
AKS_FLUX_COMMIT_USER_NAME=github-actions[bot]
AKS_FLUX_COMMIT_USER_EMAIL=41898282+github-actions[bot]@users.noreply.github.com
POST_DEPLOY_API_TEST_PATH=/weatherforecast
POST_DEPLOY_EXPECTED_MIN_ITEMS=1
K6_VUS=15
K6_DURATION=30s
K6_P95_MS=1500
```

Secrets used with this example:

- `AKS_FLUX_GITOPS_TOKEN` when the GitOps repository is separate from this repository
- `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, and `AZURE_SUBSCRIPTION_ID` only if the workflow also needs Azure-authenticated steps in the same environment

Suggested environment usage:

- `dev`: GitOps path and URL for development cluster
- `staging`: GitOps path and URL for staging cluster
- `production`: GitOps path and URL for production cluster plus required reviewers in the GitHub `production` environment

## Manual workflow inputs

`ci.yaml` supports these `workflow_dispatch` inputs:

- `sonar_enabled`: defaults to `true`

## Configuration matrix

- `AZURE_CLIENT_ID`: secret, required for Azure-backed CD login
- `AZURE_TENANT_ID`: secret, required for Azure-backed CD login
- `AZURE_SUBSCRIPTION_ID`: secret, required for Azure-backed CD login
- `DEPENDENCY_TRACK_URL`: optional secret for BOM upload
- `DEPENDENCY_TRACK_API_KEY`: optional secret for BOM upload
- `SONAR_TOKEN`: optional secret for Sonar scan
- `SONAR_PROJECT_KEY`: optional secret for Sonar scan metadata
- `SONAR_ORGANIZATION`: optional secret for SonarCloud
- `SONAR_HOST_URL`: optional secret for self-hosted SonarQube
- `SNYK_TOKEN`: optional secret for Snyk app, image, and IaC scans
- `GITLEAKS_LICENSE`: optional secret for organization-owned repository scans
- `AKS_FLUX_GITOPS_TOKEN`: optional secret for Flux mode when pushing to a separate GitOps repository
- `DEPLOY_TARGET`: environment variable, required for CD target selection, `aca` or `aks`
- `TARGET_API_URL`: optional environment variable for shared published deployed address override used by smoke, k6, and ZAP
- `POST_DEPLOY_API_TEST_PATH`: optional environment variable for post-deploy smoke and k6 endpoint path
- `POST_DEPLOY_EXPECTED_MIN_ITEMS`: optional environment variable for post-deploy smoke and k6 minimum expected array length
- `K6_VUS`: optional environment variable for post-deploy k6 virtual users
- `K6_DURATION`: optional environment variable for post-deploy k6 duration
- `K6_P95_MS`: optional environment variable for post-deploy k6 p95 threshold in milliseconds
- `AZURE_RESOURCE_GROUP`: environment variable, required for Azure Container Apps deploys
- `CONTAINER_APP_NAME`: environment variable, required for Azure Container Apps deploys
- `AKS_DEPLOY_MODE`: environment variable, required for AKS deploys, `direct` or `flux`
- `AKS_RESOURCE_GROUP`: environment variable, required for AKS cluster lookup
- `AKS_CLUSTER_NAME`: environment variable, required for AKS cluster lookup
- `AKS_MANIFESTS_PATH`: environment variable, required for AKS direct mode
- `AKS_NAMESPACE`: optional environment variable for AKS direct mode, defaults to `default`
- `AKS_ROLLOUT_TIMEOUT`: optional environment variable for AKS direct rollout timeout
- `AKS_TARGET_API_URL`: environment variable, required for AKS when `TARGET_API_URL` is not shared
- `AKS_FLUX_GITOPS_REPOSITORY`: environment variable, required for AKS Flux mode
- `AKS_FLUX_GITOPS_BRANCH`: optional environment variable for AKS Flux mode, defaults to `main`
- `AKS_FLUX_MANIFEST_PATH`: environment variable, required for AKS Flux mode
- `AKS_FLUX_IMAGE_REPOSITORY`: environment variable, required for AKS Flux mode
- `AKS_FLUX_COMMIT_USER_NAME`: optional environment variable for AKS Flux commit author name
- `AKS_FLUX_COMMIT_USER_EMAIL`: optional environment variable for AKS Flux commit author email
- `SONAR_CI_ENABLED`: optional repository variable to disable Sonar by default in CI

## Related documents

- [CI/CD Pipeline Guide](ci-cd-pipeline.md)
- [Security Configuration](security-config.md)
- [Troubleshooting](troubleshooting.md)
