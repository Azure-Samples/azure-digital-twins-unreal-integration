using System;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using Microsoft.Rest;
using Microsoft.Azure;
using Microsoft.Azure.TimeSeriesInsights;
using Microsoft.Azure.TimeSeriesInsights.Models;
using Microsoft.IdentityModel.Clients.ActiveDirectory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Configuration;

namespace TsiWebApp.Models
{
    public interface ITimeSeriesInsightsClient
    {
        Task InitializeAsync();
        GetEvents GetEventsRequest(string timeSeriesId, DateTimeRange searchSpan, EventProperty eventProperty, bool ignoreNull = true);
        Task<List<QueryResultPage>> GetEventsAsync(GetEvents getEventsRequest);
        //AggregateSeries GetAggregateSeriesRequest(string timeSeriesId, DateTimeRange searchSpan, TimeSpan interval, EventProperty eventProperty);
        //Task<List<QueryResultPage>> GetAggregateSeriesAsync(AggregateSeries aggregateSeries);
        Task<List<QueryResultPage>> GetAggregateSeriesAsync(string[] timeSeriesIds, DateTimeRange searchSpan, TimeSpan interval, EventProperty eventProperty);
    }

    public class TimeSeriesInsightsClient : ITimeSeriesInsightsClient
    {
        private readonly string _resourceUri;
        private readonly string _clientId;
        private readonly string _clientSecret;
        private readonly string _aadLoginUrl;
        private readonly string _tenantId;
        private readonly string _environmentFqdn;
        private readonly HttpClient HttpClient;
        private readonly ILogger<ITimeSeriesInsightsClient> _logger;
        private Microsoft.Azure.TimeSeriesInsights.TimeSeriesInsightsClient Client { get; set; }

        /// <summary>
        /// Available options to render Y axis data
        /// </summary>
        public enum YAxisState
        {
            shared,
            stacked,
            overlap,
        }

        /// <summary>
        /// Available sensor types
        /// </summary>
        public enum SensorType
        {
            hvac,
            lighting,
            temp,
            occupancy,
        }

        /// <summary>
        /// Legend options to use in the chart
        /// </summary>
        public enum Legend
        {
            shown,
            hidden,
            compact,
        }

        /// <summary>
        /// Theme options to use in the chart
        /// </summary>
        public enum Theme
        {
            dark,
            light,
        }

        /// <summary>
        /// Class constructor
        /// </summary>
        /// <param name="configuration"></param>
        public TimeSeriesInsightsClient(IConfiguration configuration, HttpClient httpClient, ILogger<ITimeSeriesInsightsClient> logger)
        {
            _logger = logger;
            HttpClient = httpClient;
            _resourceUri = configuration["RESOURCE_URI"];
            _clientId = configuration["CLIENT_ID"];
            _clientSecret = configuration["CLIENT_SECRET"];
            _aadLoginUrl = configuration["AAD_LOGIN_URL"];
            _tenantId = configuration["TENANT_ID"];
            _environmentFqdn = configuration["TSI_ENV_FQDN"];
        }

        /// <summary>
        /// Initialize client, authenticates with Azure Active Directory using service principal credentials
        /// </summary>
        /// <returns></returns>
        public async Task InitializeAsync()
        {
            try
            {
                AuthenticationContext context = new AuthenticationContext($"{new Uri(_aadLoginUrl)}/{_tenantId}", TokenCache.DefaultShared);
                AuthenticationResult authenticationResult = await context.AcquireTokenAsync(_resourceUri, new ClientCredential(_clientId, _clientSecret));

                TokenCloudCredentials tokenCloudCredentials = new TokenCloudCredentials(authenticationResult.AccessToken);
                ServiceClientCredentials serviceClientCredentials = new TokenCredentials(tokenCloudCredentials.Token);

                this.Client = new Microsoft.Azure.TimeSeriesInsights.TimeSeriesInsightsClient(credentials: serviceClientCredentials)
                {
                    EnvironmentFqdn = _environmentFqdn,
                };
            }
            catch (Exception e)
            {
                this._logger.LogError(e.ToString());
                throw e;
            }
        }

        /// <summary>
        /// Get sensor array
        /// </summary>
        /// <param name="sensorType"></param>
        /// <param name="sensorIndexStart"></param>
        /// <param name="sensorCount"></param>
        /// <returns></returns>
        public static string[] GetTimeSeriesIdArray(SensorType sensorType, int sensorIndexStart = 1, int sensorCount = 3)
        {
            string[] sensorArray = Enumerable.Range(sensorIndexStart, sensorCount).Select(x => { return $"{sensorType}sensor{x}"; }).ToArray();
            return sensorArray;
        }

        /// <summary>
        /// Convert time range
        /// </summary>
        /// <param name="since">time range as a duration</param>
        /// <returns></returns>
        public static DateTimeRange GetTimeRange(string since)
        {
            try
            {
                since = since.ToLower();
                DateTime to = DateTime.UtcNow;
                DateTime from = to;
                Match match = Regex.Match(since, @"((\d+?)h)?((\d+?)m)?((\d+?)s)?");

                if (!string.IsNullOrEmpty(match.Groups[2].Value))
                    from = from.AddHours(-1 * Convert.ToInt32(match.Groups[2].Value));

                if (!string.IsNullOrEmpty(match.Groups[4].Value))
                    from = from.AddMinutes(-1 * Convert.ToInt32(match.Groups[4].Value));

                if (!string.IsNullOrEmpty(match.Groups[6].Value))
                    from = from.AddSeconds(-1 * Convert.ToInt32(match.Groups[6].Value));

                var dateTimeRange = new DateTimeRange()
                {
                    FromProperty = from,
                    To = to,
                };

                return dateTimeRange;
            }
            catch (Exception e)
            {
                throw e;
            }
        }

        /// <summary>
        /// Get time interval from interval expressions like PT?[DHMS]
        /// </summary>
        /// <param name="interval">interval expression</param>
        /// <returns></returns>
        public static TimeSpan GetTimeInterval(string interval)
        {
            try
            {
                interval = interval.ToLower();
                Match match = Regex.Match(interval, @"pt(\d+)([dhms])");

                int intervalFactor = match.Groups[2].Value switch
                {
                    "s" => 1,
                    "m" => 60,
                    "h" => 60 * 60,
                    "d" => 60 * 60 * 24,
                    _ => throw new Exception($"Time interval {interval} cannot be parsed"),
                };

                int totalSeconds = Convert.ToInt32(match.Groups[1].Value) * intervalFactor;

                return new TimeSpan(0, 0, totalSeconds);
            }
            catch (Exception e)
            {
                throw e;
            }

        }

        /// <summary>
        /// Create event property object based on sensor type
        /// </summary>
        /// <param name="sensorType"></param>
        /// <returns></returns>
        public static EventProperty GetEventProperty(SensorType sensorType)
        {
            var eventProperty = new EventProperty(
                sensorType switch
                {
                    SensorType.hvac => "airflow",
                    SensorType.lighting => "State",
                    SensorType.temp => "temperature",
                    SensorType.occupancy => "IsOccupied",
                    _ => throw new Exception($"sensor type '{sensorType}' is not defined"),
                },
                sensorType switch
                {
                    SensorType.hvac => "Long",
                    SensorType.lighting => "Long",
                    SensorType.temp => "Double",
                    SensorType.occupancy => "Long",
                    _ => throw new Exception($"sensor type '{sensorType}' is not defined"),
                });

            return eventProperty;
        }

        /// <summary>
        /// Creates event request object based on input parameters
        /// </summary>
        /// <param name="sensorType"></param>
        /// <param name="timeSeriesId"></param>
        /// <param name="searchSpan"></param>
        /// <param name="ignoreNull"></param>
        /// <returns></returns>
        public GetEvents GetEventsRequest(string timeSeriesId, DateTimeRange searchSpan, EventProperty eventProperty, bool ignoreNull = true)
        {
            try
            {
                // timeSeriesId
                var timeSeriesIds = new string[]
                {
                    timeSeriesId
                };

                // projectedProperties
                var projectedProperties = new List<EventProperty>() { eventProperty };

                // inlineVariables
                var inlineVariables = new Dictionary<string, Variable>()
                {
                    { eventProperty.Type, new Variable(new Tsx($"event.{projectedProperties[0].Name}.{projectedProperties[0].Type}")) }
                };

                // filter
                Tsx filter = null;
                if (ignoreNull)
                    filter = new Tsx($"$event.{projectedProperties[0].Name}.{projectedProperties[0].Type} != null");

                var getEventsRequest = new GetEvents(timeSeriesIds, searchSpan, filter, projectedProperties);

                return getEventsRequest;
            }
            catch (Exception e)
            {
                this._logger.LogError(e.ToString());
                throw e;
            }
        }

        /// <summary>
        /// Gets raw event data from TSI
        /// </summary>
        /// <param name="request"></param>
        /// <returns></returns>
        public async Task<List<QueryResultPage>> GetEventsAsync(GetEvents getEventsRequest)
        {
            try
            {
                List<QueryResultPage> queryResultPages = new List<QueryResultPage>() { };
                QueryRequest queryRequest = new QueryRequest(getEvents: getEventsRequest);

                string continuationToken;
                do
                {
                    QueryResultPage queryResponse = await this.Client.Query.ExecuteAsync(queryRequest);
                    queryResultPages.Add(queryResponse);

                    continuationToken = queryResponse.ContinuationToken;
                }
                while (continuationToken != null);

                return queryResultPages;
            }
            catch (Exception e)
            {
                this._logger.LogError(e.ToString());
                throw e;
            }
        }

        /// <summary>
        /// Creates aggregates series request object based on input parameters
        /// </summary>
        /// <param name="sensorType"></param>
        /// <param name="timeSeriesId"></param>
        /// <param name="searchSpan"></param>
        /// <param name="interval"></param>
        /// <param name="ignoreNull"></param>
        /// <returns></returns>
        private AggregateSeries GetAggregateSeriesRequest(string timeSeriesId, DateTimeRange searchSpan, TimeSpan interval, EventProperty eventProperty)
        {
            try
            {
                var timeSeriesIds = new string[] { timeSeriesId };

                var inlineVariable = new InlineVariable(
                    "numeric",
                    new Tsx($"$event.{eventProperty.Name}.{eventProperty.Type}"),
                    new Tsx("avg($value)"));

                var inlineVariables = new Dictionary<string, InlineVariable>() { { eventProperty.Name, inlineVariable } };

                var projectedVariables = new string[] { eventProperty.Name };

                var aggregateSeries = new AggregateSeries(
                    timeSeriesIds, 
                    searchSpan: searchSpan, 
                    interval: interval,
                    inlineVariables: inlineVariables,
                    projectedVariables: projectedVariables);

                return aggregateSeries;
            }
            catch (Exception e)
            {
                this._logger.LogError(e.ToString());
                throw e;
            }
        }

        /// <summary>
        /// Get aggregate series data from TSI
        /// </summary>
        /// <param name="aggregateSeries"></param>
        /// <returns></returns>
        private async Task<List<QueryResultPage>> GetAggregateSeriesAsync(AggregateSeries aggregateSeries)
        {
            try
            {
                List<QueryResultPage> queryResultPages = new List<QueryResultPage>() { };
                QueryRequest queryRequest = new QueryRequest(aggregateSeries: aggregateSeries);

                string continuationToken;
                do
                {
                    QueryResultPage queryResponse = await this.Client.Query.ExecuteAsync(queryRequest);
                    queryResultPages.Add(queryResponse);

                    continuationToken = queryResponse.ContinuationToken;
                }
                while (continuationToken != null);

                return queryResultPages;
            }
            catch (Exception e)
            {
                throw e;
            }
        }

        /// <summary>
        /// Get aggregate series data from TSI
        /// </summary>
        /// <param name="sensorType"></param>
        /// <param name="sensorCount"></param>
        /// <param name="searchSpan"></param>
        /// <param name="interval"></param>
        /// <returns></returns>
        public async Task<List<QueryResultPage>> GetAggregateSeriesAsync(string[] timeSeriesIds, DateTimeRange searchSpan, TimeSpan interval, EventProperty eventProperty)
        {
            try
            {
                var queryResultPages = new List<QueryResultPage>();
                
                foreach (var timeSeriesId in timeSeriesIds)
                {
                    var aggregateSeriesRequest = GetAggregateSeriesRequest(timeSeriesId, searchSpan, interval, eventProperty);
                    var queryResult = await GetAggregateSeriesAsync(aggregateSeriesRequest);

                    queryResultPages.AddRange(queryResult);
                }

                return queryResultPages;
            }
            catch (Exception e)
            {
                throw e;
            }
        }
    }
}
