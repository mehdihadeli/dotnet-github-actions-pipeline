import http from "k6/http";
import { check, sleep } from "k6";

const baseUrl = (__ENV.BASE_URL || "").replace(/\/$/, "");
const apiPath = (__ENV.API_PATH || "/weatherforecast").startsWith("/")
  ? __ENV.API_PATH || "/weatherforecast"
  : `/${__ENV.API_PATH}`;
const expectedMinItems = Number.parseInt(__ENV.EXPECTED_MIN_ITEMS || "1", 10);
const vus = Number.parseInt(__ENV.K6_VUS || "5", 10);
const duration = __ENV.K6_DURATION || "15s";
const p95Threshold = Number.parseInt(__ENV.K6_P95_MS || "1000", 10);

if (!baseUrl) {
  throw new Error("BASE_URL environment variable is required.");
}

export const options = {
  vus,
  duration,
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: [`p(95)<${p95Threshold}`],
    checks: ["rate==1.0"],
  },
};

export default function () {
  const response = http.get(`${baseUrl}${apiPath}`, {
    headers: {
      Accept: "application/json",
    },
  });

  const payload = response.json();

  check(response, {
    "status is 200": (res) => res.status === 200,
    "content type is json": (res) =>
      (res.headers["Content-Type"] || "").includes("application/json"),
    "payload is array": () => Array.isArray(payload),
    "payload has expected items": () =>
      Array.isArray(payload) && payload.length >= expectedMinItems,
    "payload contains forecast shape": () =>
      Array.isArray(payload) &&
      payload.every(
        (item) =>
          item.date &&
          Object.prototype.hasOwnProperty.call(item, "temperatureC") &&
          Object.prototype.hasOwnProperty.call(item, "temperatureF") &&
          Object.prototype.hasOwnProperty.call(item, "summary"),
      ),
  });

  sleep(1);
}
