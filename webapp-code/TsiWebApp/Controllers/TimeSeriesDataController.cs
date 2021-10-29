using System;
using System.Linq;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;
using TsiWebApp.Models;
using static TsiWebApp.Models.TimeSeriesInsightsClient;

namespace TsiWebApp.Controllers
{
    public class TimeSeriesDataController : Controller
    {
        private readonly int _sensorCount;
        private readonly ITimeSeriesInsightsClient _tsiClient;
        private readonly ILogger<TimeSeriesDataController> _logger;

        public TimeSeriesDataController(IConfiguration configuration, ITimeSeriesInsightsClient timeSeriesInsightsClient, ILogger<TimeSeriesDataController> logger) 
        {
            this._logger = logger;
            this._sensorCount = Convert.ToInt32(configuration["SENSOR_COUNT"]);
            this._tsiClient = timeSeriesInsightsClient;
        }

        /// <summary>
        /// Display TSI data on HTML format
        /// </summary>
        /// <param name="sensorType">Sensor type: hvac, temp, lighting, occupancy</param>
        /// <param name="since">Only return logs since this time, as a duration: 1h, 20m, 2h30m</param>
        /// <param name="dataFormat">How to display all the data streams: overlapped, separate</param>
        /// <param name="ignoreNull">Whether to ignore null data points</param>
        /// <returns></returns>
        [HttpGet]
        public async Task<IActionResult> Index(
            SensorType sensorType,
            string since = "60m",
            string interval = "pt3m",
            YAxisState yAxis = YAxisState.stacked,
            Theme theme = Theme.dark,
            Legend legend = Legend.hidden,
            int width = 350,
            int height = 205)
        {
            try
            {
                await this._tsiClient.InitializeAsync();
                var timeSeriesIds = TimeSeriesInsightsClient.GetTimeSeriesIdArray(sensorType, 1, _sensorCount);
                var eventProperty = TimeSeriesInsightsClient.GetEventProperty(sensorType);
                var searchSpan = TimeSeriesInsightsClient.GetTimeRange(since);
                var timeInterval = TimeSeriesInsightsClient.GetTimeInterval(interval);
                var aggregateSeries = await this._tsiClient.GetAggregateSeriesAsync(timeSeriesIds, searchSpan, timeInterval, eventProperty);
                string serializedData = JsonConvert.SerializeObject(aggregateSeries);

                ViewData["TimeSeriesIds"] = JsonConvert.SerializeObject(timeSeriesIds);
                ViewData["Data"] = serializedData;
                ViewData["From"] = searchSpan.FromProperty.ToString("yyyy-MM-ddTHH:mm:00.000Z");
                ViewData["To"] = searchSpan.To.ToString("yyyy-MM-ddTHH:mm:00.000Z");
                ViewData["BucketSize"] = $"{timeInterval.TotalSeconds}s";
                ViewData["VariableType"] = "numeric";
                ViewData["VariableName"] = eventProperty.Name;
                ViewData["VariableValue"] = $"$event.{eventProperty.Name}.{eventProperty.Type}";
                ViewData["VariableAggregation"] = "avg($value)";
                ViewData["yAxisState"] = yAxis.ToString();
                ViewData["Theme"] = theme.ToString();
                ViewData["Legend"] = legend.ToString();
                ViewData["Width"] = $"{width}px";
                ViewData["Height"] = $"{height}px";

                return View();
            }
            catch (Exception e)
            {
                ViewData["Error"] = e.ToString();
                this._logger.LogError(e.ToString());
                return View("Error");
            }
        }
    }
}
