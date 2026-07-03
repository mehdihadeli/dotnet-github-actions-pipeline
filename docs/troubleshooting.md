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

- publish is optional
- manual runs require `publish_image=true`
- branch and tag policy still controls when publish is allowed

## CD issues

### Deployment did not start

Checks:

- verify the triggering CI run concluded successfully
- verify the `ci-evidence` artifact exists
- verify evidence contains `autoDeploy=true`
- verify a target environment and signed or verified image digest are present

### Deploy job skipped because of missing config

Checks:

- verify target GitHub environment has `AZURE_RESOURCE_GROUP`
- verify target GitHub environment has `CONTAINER_APP_NAME`

### Azure login fails

Checks:

- verify `AZURE_CLIENT_ID`
- verify `AZURE_TENANT_ID`
- verify `AZURE_SUBSCRIPTION_ID`

### ZAP target cannot be resolved

Checks:

- set `STAGED_API_URL` when automatic Container App FQDN resolution is not sufficient
- verify Container App ingress is public and resolvable

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
