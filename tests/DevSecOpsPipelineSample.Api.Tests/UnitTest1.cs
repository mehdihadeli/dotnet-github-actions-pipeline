using DevSecOpsPipelineSample.Api.Controllers;

namespace DevSecOpsPipelineSample.Api.Tests;

public class UnitTest1
{
    [Fact]
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
}
