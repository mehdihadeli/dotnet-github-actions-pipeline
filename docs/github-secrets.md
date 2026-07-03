# GitHub Secrets and Variables

This document collects the GitHub configuration expected by the CI and CD workflows.

## Built-in token usage

The sample uses the repository-scoped `GITHUB_TOKEN` for:

- GHCR login and publish
- Gitleaks GitHub integration
- artifact and workflow API access in CD

A separate `GHCR_TOKEN` is not required.

## Required secrets for CD deployment

These secrets are required when you want the deployment stage to authenticate to Azure:

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

## Repository variables

Optional repository variables:

- `SONAR_CI_ENABLED=false`

When unset, CI-based Sonar analysis defaults to enabled.

## Environment variables for CD environments

The `deploy` job reads environment-scoped variables from the target environment.

Required variables:

- `AZURE_RESOURCE_GROUP`
- `CONTAINER_APP_NAME`

Optional variable:

- `STAGED_API_URL`

If `STAGED_API_URL` is not provided, the CD workflow tries to resolve the public Azure Container App FQDN automatically.

## Manual workflow inputs

`ci.yaml` supports these `workflow_dispatch` inputs:

- `sonar_enabled`: defaults to `true`
- `publish_image`: defaults to `false`

## Configuration matrix

| Setting                    | Type                 | Required  | Used by                        |
| -------------------------- | -------------------- | --------- | ------------------------------ |
| `AZURE_CLIENT_ID`          | secret               | CD deploy | Azure login                    |
| `AZURE_TENANT_ID`          | secret               | CD deploy | Azure login                    |
| `AZURE_SUBSCRIPTION_ID`    | secret               | CD deploy | Azure login                    |
| `DEPENDENCY_TRACK_URL`     | secret               | Optional  | BOM upload                     |
| `DEPENDENCY_TRACK_API_KEY` | secret               | Optional  | BOM upload                     |
| `SONAR_TOKEN`              | secret               | Optional  | Sonar scan                     |
| `SONAR_PROJECT_KEY`        | secret               | Optional  | Sonar scan                     |
| `SONAR_ORGANIZATION`       | secret               | Optional  | SonarCloud                     |
| `SONAR_HOST_URL`           | secret               | Optional  | Self-hosted SonarQube          |
| `SNYK_TOKEN`               | secret               | Optional  | Snyk app, image, and IaC scans |
| `GITLEAKS_LICENSE`         | secret               | Optional  | Gitleaks org use               |
| `AZURE_RESOURCE_GROUP`     | environment variable | CD deploy | Azure Container Apps           |
| `CONTAINER_APP_NAME`       | environment variable | CD deploy | Azure Container Apps           |
| `STAGED_API_URL`           | environment variable | Optional  | ZAP target override            |
| `SONAR_CI_ENABLED`         | repository variable  | Optional  | Sonar default toggle           |

## Related documents

- [CI/CD Pipeline Guide](ci-cd-pipeline.md)
- [Security Configuration](security-config.md)
- [Troubleshooting](troubleshooting.md)
