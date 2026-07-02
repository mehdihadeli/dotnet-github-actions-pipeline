# Dependency-Track Local Stack

This folder provides a local Dependency-Track stack for the sample pipeline.

Services:

- Dependency-Track API server on `http://localhost:8081`
- Dependency-Track frontend on `http://localhost:8080`
- PostgreSQL backing database on `localhost:5432`
- Trivy server on `http://localhost:4954`

## Start

```bash
cp .env.example .env
docker compose up -d
```

The stack also includes an optional one-shot bootstrap container named `dtrack-bootstrap`. It configures Dependency-Track's Trivy analyzer through the REST API after the API server and Trivy server are reachable.

If `DEPENDENCY_TRACK_API_KEY` is empty, the bootstrap container exits without changing anything.

## Configure Trivy in Dependency-Track

Dependency-Track integrates with Trivy through client/server mode. After the stack is running:

1. Open the Dependency-Track UI.
2. Go to `Administration -> Analyzers -> Trivy`.
3. Enable the analyzer.
4. Set `Base URL` to `http://trivy:8080`.
5. Set `API Token` to the same value as `TRIVY_SERVER_TOKEN` in `.env`.
6. Optional: enable `Ignore Unfixed` if that fits your policy.

Using `http://trivy:8080` is important because the Dependency-Track API server reaches Trivy over the internal Docker Compose network, not through the host-mapped port.

## Optional API bootstrap

If you already have an API key with `SYSTEM_CONFIGURATION` permission, put it in `.env`:

```bash
DEPENDENCY_TRACK_API_KEY=odt_your_admin_key
```

Then rerun the bootstrap container:

```bash
docker compose up dtrack-bootstrap
```

The bootstrap script waits for:

- Dependency-Track backend OpenAPI endpoint at `http://dtrack-apiserver:8080/api/openapi.json`
- Trivy health endpoint at `http://trivy:8080/healthz`

Then it posts these config properties through `POST /api/v1/configProperty/aggregate`:

- `scanner.trivy.enabled=true`
- `scanner.trivy.base.url=http://trivy:8080`
- `scanner.trivy.api.token=${TRIVY_SERVER_TOKEN}`
- `scanner.trivy.ignore.unfixed=${TRIVY_IGNORE_UNFIXED}`

Script path:

- [bootstrap-trivy.sh](https://github.com/mehdihadeli/dotnet-github-actions-pipeline/blob/main/deployments/dependency-track/bootstrap-trivy.sh)

## How this fits sample pipeline

The sample repository already includes a reusable upload action at `.github/actions/upload-dependency-track-bom/action.yml`.

When `DEPENDENCY_TRACK_URL` and `DEPENDENCY_TRACK_API_KEY` are configured in GitHub, CI can upload application and image CycloneDX BOM files to Dependency-Track.

Exact upload locations in CI:

- app SBOM upload: `dotnet-app-sca-security -> Upload app SBOM to Dependency-Track`
- image SBOM upload: `image-sca-security -> Upload image SBOM to Dependency-Track`

Both jobs call the same reusable action:

- `.github/actions/upload-dependency-track-bom/action.yml`

The app upload sends:

- `bom-file=artifacts/sbom/app/bom.json`
- `project-name=${APP_SBOM_PROJECT_NAME}`
- `project-version=${github.sha}`

The image upload sends:

- `bom-file=artifacts/sbom/image/image.cdx.json`
- `project-name=${APP_SBOM_PROJECT_NAME}-image`
- `project-version=${github.sha}`

Suggested URL for GitHub-hosted integration against this local stack:

- `DEPENDENCY_TRACK_URL=http://host.docker.internal:8081`

For local experiments outside GitHub Actions, use the frontend at `http://localhost:8080` and create an API key from the Dependency-Track administration UI.

## Warm up Dependency-Track with sample SBOMs

If you want to validate the local stack before wiring it to a real GitHub Actions run, warm it up with the sample app and image SBOMs.

Expected project names. These match CI defaults:

- `devsecops-pipeline-sample`
- `devsecops-pipeline-sample-image`

Example version value:

- `COMMIT_SHA`

### Option 1: Upload from the UI

1. Open `http://localhost:8080`.
2. Go to `Projects`.
3. Create or open the target project.
4. Click `Upload BOM`.
5. Upload app SBOM first, then image SBOM to the image project.

Recommended mapping:

- app project `devsecops-pipeline-sample` -> `bom.json`
- image project `devsecops-pipeline-sample-image` -> `image.cdx.json`

### Option 2: Upload through the local API

If you already have an API key, you can warm up the projects directly with curl.

App SBOM:

```bash
curl -fsS -X POST "http://localhost:8081/api/v1/bom" \
  -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" \
  -F "autoCreate=true" \
  -F "projectName=devsecops-pipeline-sample" \
  -F "projectVersion=COMMIT_SHA" \
  -F "bom=@path/to/bom.json"
```

Image SBOM:

```bash
curl -fsS -X POST "http://localhost:8081/api/v1/bom" \
  -H "X-Api-Key: ${DEPENDENCY_TRACK_API_KEY}" \
  -F "autoCreate=true" \
  -F "projectName=devsecops-pipeline-sample-image" \
  -F "projectVersion=COMMIT_SHA" \
  -F "bom=@path/to/image.cdx.json"
```

### Where to get the two SBOM files

Best source is the CI artifact published by the `Record and notify` job in a successful CI run.

Warmup flow:

1. open the finished CI run
2. download the artifact produced by `Record and notify`
3. extract the artifact locally
4. use these two files for Dependency-Track upload

Expected paths inside the downloaded artifact:

- app SBOM: `artifacts/sbom/app/bom.json`
- image SBOM: `artifacts/sbom/image/image.cdx.json`

That path is better than rebuilding locally because you validate the exact BOM files produced by the pipeline you want to trust.

From a local repo run, those are still the same output paths after the SBOM generation steps complete.

### What you should see in the UI

After upload:

- `devsecops-pipeline-sample` should show the application dependency inventory
- `devsecops-pipeline-sample-image` should show the container/runtime inventory
- image project usually surfaces more CVEs because it includes OS and runtime packages

Best places to inspect:

- `Components`
- `Vulnerabilities`
- `Dependency Graph`
- `Audit Vulnerabilities`

This warmup is useful because it proves three things before you rely on the full pipeline:

- local Dependency-Track API accepts CycloneDX BOM uploads
- app and image SBOMs stay separate in the portfolio
- vulnerability analysis is visible in the UI before CI networking is involved
