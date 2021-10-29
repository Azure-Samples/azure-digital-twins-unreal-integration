// Default URL for triggering event grid function in the local environment.
// http://localhost:7071/runtime/webhooks/EventGrid?functionName={functionname}
using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Azure.EventGrid.Models;
using Microsoft.Azure.WebJobs.Extensions.EventGrid;
using Microsoft.Extensions.Logging;
using Azure;
using Azure.Core.Pipeline;
using Azure.DigitalTwins.Core;
using Azure.Identity;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Net.Http;


namespace Unreal
{
    public static class ADT
    {

        private static readonly string adtInstanceUrl = Environment.GetEnvironmentVariable("ADT_SERVICE_URL");
        private static readonly HttpClient httpClient = new HttpClient();

        [FunctionName("IoTHubIngest")]
        public static void Run([EventGridTrigger]EventGridEvent eventGridEvent, ILogger log)
        {
            if (adtInstanceUrl == null) log.LogError("Application setting \"ADT_SERVICE_URL\" not set");
            log.LogInformation($"ADT instance: {adtInstanceUrl} ");

            try
            {
                //Authenticate with Digital Twins
                DefaultAzureCredential cred = new DefaultAzureCredential();
                var token = cred.GetToken(new Azure.Core.TokenRequestContext(new string[] { "https://digitaltwins.azure.net" }));
                DigitalTwinsClient client = new DigitalTwinsClient(new Uri(adtInstanceUrl), cred, new DigitalTwinsClientOptions { Transport = new HttpClientTransport(httpClient) });
                log.LogInformation($"ADT service client connection created.");
                if (eventGridEvent != null && eventGridEvent.Data != null)
                {
                    log.LogInformation(eventGridEvent.Data.ToString());

                    JObject deviceMessage = (JObject)JsonConvert.DeserializeObject(eventGridEvent.Data.ToString());
                    string deviceId = (string)deviceMessage["systemProperties"]["iothub-connection-device-id"];
                    var updateTwinData = new JsonPatchDocument();

                    if (deviceMessage.SelectToken("body.temperature", errorWhenNoMatch: false) != null)
                    {
                        log.LogInformation($"Device:{deviceId} contains temperature data");
                        updateTwinData.AppendAdd("/temperature", deviceMessage["body"]["temperature"].Value<double>());
                    }
                    if (deviceMessage.SelectToken("body.airflow", errorWhenNoMatch: false) != null)
                    {
                        log.LogInformation($"Device:{deviceId} contains airflow data");
                        updateTwinData.AppendAdd("/airflow", deviceMessage["body"]["airflow"].Value<double>());
                    }
                    if (deviceMessage.SelectToken("body.IsOccupied", errorWhenNoMatch: false) != null)
                    {
                        log.LogInformation($"Device:{deviceId} contains presence data");
                        //                        updateTwinData.AppendAdd("/presence", deviceMessage["body"]["presence"].Value<bool>());
                        updateTwinData.AppendAdd("/IsOccupied", deviceMessage["body"]["IsOccupied"].Value<bool>());
                    }
                    if (deviceMessage.SelectToken("body.State", errorWhenNoMatch: false) != null)
                    {
                        log.LogInformation($"Device:{deviceId} contains lighting data");
                        //                        updateTwinData.AppendAdd("/presence", deviceMessage["body"]["presence"].Value<bool>());
                        updateTwinData.AppendAdd("/State", deviceMessage["body"]["State"].Value<bool>());
                    }
                    log.LogInformation($"Sending patch document for device {deviceId}:  {updateTwinData.ToString()}");
                    client.UpdateDigitalTwinAsync(deviceId, updateTwinData).ConfigureAwait(true).GetAwaiter().GetResult();
                }
            }
            catch (Exception e)
            {
                log.LogError(e.ToString());
                throw e;
            }
        }
    }
}
