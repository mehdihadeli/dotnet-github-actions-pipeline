using DevSecOpsPipelineSample.Api;
using DevSecOpsPipelineSample.Api.Controllers;

namespace DevSecOpsPipelineSample.UnitTests;

public class WeatherForecastControllerTests
{
    [Fact]
    [Trait("TestSuite", "Unit")]
    public void Get_ReturnsFiveForecasts_WithSummaries()
    {
        var controller = new WeatherForecastController();

        var forecasts = controller.Get().ToArray();

        Assert.Equal(5, forecasts.Length);
        Assert.All(
            forecasts,
            forecast => Assert.False(string.IsNullOrWhiteSpace(forecast.Summary))
        );
    }

    [Theory]
    [Trait("TestSuite", "Unit")]
    [InlineData(0, 32)]
    [InlineData(25, 76)]
    [InlineData(-10, 15)]
    public void TemperatureF_ConvertsFromCelsius(int temperatureC, int expectedTemperatureF)
    {
        var forecast = new WeatherForecast { TemperatureC = temperatureC };

        Assert.Equal(expectedTemperatureF, forecast.TemperatureF);
    }
}
