# DevSecOpsPipelineSample.K6Tests

This folder contains the k6 script used by the CD workflow after deployment.

## Purpose

- validate the deployed target endpoint responds with HTTP 200
- validate the response is JSON
- validate the payload shape matches the expected forecast schema
- enforce a short latency threshold before the ZAP baseline stage runs

## Script

- `target-api-check.js`

## Required environment variables

- `BASE_URL`: deployed application base URL, for example `https://api.contoso.com`

## Optional environment variables

- `API_PATH`: endpoint path to test, defaults to `/weatherforecast`
- `EXPECTED_MIN_ITEMS`: minimum expected array length, defaults to `1`
- `K6_VUS`: number of virtual users, defaults to `5`
- `K6_DURATION`: test duration, defaults to `15s`
- `K6_P95_MS`: p95 latency threshold in milliseconds, defaults to `1000`

## Current thresholds

- `http_req_failed`: `rate<0.01`
- `http_req_duration`: `p(95)<K6_P95_MS`
- `checks`: `rate==1.0`

## Local usage

```bash
k6 run tests/DevSecOpsPipelineSample.K6Tests/target-api-check.js
```

Example:

```bash
BASE_URL=https://localhost:5001 \
API_PATH=/weatherforecast \
EXPECTED_MIN_ITEMS=1 \
K6_VUS=5 \
K6_DURATION=15s \
K6_P95_MS=1000 \
k6 run tests/DevSecOpsPipelineSample.K6Tests/target-api-check.js
```

## CI/CD usage

The CD workflow reads these values from GitHub environment variables and runs this script after deploy, before the ZAP baseline stage.
