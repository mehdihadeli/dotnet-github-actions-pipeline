# API Reference

This repository contains a small ASP.NET Core API used as the application surface for the DevSecOps pipeline.

## Runtime model

- framework: ASP.NET Core on .NET 10
- controller-based routing
- HTTPS redirection enabled
- OpenAPI document mapped only in Development

## Endpoints

### `GET /WeatherForecast`

Returns five generated weather forecast records.

Response shape:

```json
[
  {
    "date": "2026-07-05",
    "temperatureC": 23,
    "temperatureF": 73,
    "summary": "Warm"
  }
]
```

Notes:

- `temperatureF` is computed from `temperatureC`
- `summary` is selected from a fixed in-memory list
- data is generated dynamically and is not persisted

## Models

### `WeatherForecast`

| Property       | Type       | Notes                     |
| -------------- | ---------- | ------------------------- |
| `date`         | `DateOnly` | forecast date             |
| `temperatureC` | `int`      | Celsius temperature       |
| `temperatureF` | `int`      | computed Fahrenheit value |
| `summary`      | `string?`  | descriptive label         |

## OpenAPI

The application calls `AddOpenApi()` and maps the OpenAPI endpoint only when running in Development.

Use the development environment when you want to inspect the generated schema locally.

## Local run example

```bash
dotnet run --project src/DevSecOpsPipelineSample.Api
curl https://localhost:5001/WeatherForecast
```

The exact localhost port depends on your local launch profile and ASP.NET Core configuration.

## Related documents

- [Architecture Overview](architecture.md)
- [Project Structure](project-structure.md)
