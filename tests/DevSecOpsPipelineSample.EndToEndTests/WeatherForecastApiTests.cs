using System.Net;
using System.Net.Http.Json;
using DevSecOpsPipelineSample.Api;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace DevSecOpsPipelineSample.EndToEndTests;

public class WeatherForecastApiTests
{
    [Fact]
    [Trait("TestSuite", "EndToEnd")]
    public async Task GetWeatherForecast_ReturnsExpectedPayload()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        await using var factory = new WebApplicationFactory<Program>();
        using var client = factory.CreateClient(
            new WebApplicationFactoryClientOptions { BaseAddress = new Uri("https://localhost") }
        );

        using var response = await client.GetAsync("/weatherforecast", cancellationToken);

        response.EnsureSuccessStatusCode();

        var forecasts = await response.Content.ReadFromJsonAsync<WeatherForecast[]>(
            cancellationToken
        );

        Assert.NotNull(forecasts);
        Assert.Equal(5, forecasts.Length);
        Assert.All(
            forecasts,
            forecast =>
            {
                Assert.False(string.IsNullOrWhiteSpace(forecast.Summary));
                Assert.NotEqual(default, forecast.Date);
            }
        );
    }

    [Fact]
    [Trait("TestSuite", "EndToEnd")]
    public async Task OpenApiEndpoint_IsAvailableInDevelopment()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.UseEnvironment("Development")
        );
        using var client = factory.CreateClient(
            new WebApplicationFactoryClientOptions { BaseAddress = new Uri("https://localhost") }
        );

        using var response = await client.GetAsync("/openapi/v1.json", cancellationToken);

        response.EnsureSuccessStatusCode();

        var content = await response.Content.ReadAsStringAsync(cancellationToken);

        Assert.Contains("openapi", content, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    [Trait("TestSuite", "EndToEnd")]
    public async Task OpenApiEndpoint_IsHiddenOutsideDevelopment()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        await using var factory = new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
            builder.UseEnvironment("Production")
        );
        using var client = factory.CreateClient(
            new WebApplicationFactoryClientOptions { BaseAddress = new Uri("https://localhost") }
        );

        using var response = await client.GetAsync("/openapi/v1.json", cancellationToken);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
