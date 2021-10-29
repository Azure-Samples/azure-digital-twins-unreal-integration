using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Text;
using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace UnrealAzFuncs
{
    public static class ProcessDTUpdatetoTSI
    { 
        [FunctionName("ProcessDTUpdatetoTSI")]
        public static async Task Run(
            [EventHubTrigger("twins-event-hub", Connection = "EventHubAppSetting-Twins")]EventData myEventHubMessage,
            [EventHub("tsi-event-hub", Connection = "EventHubAppSetting-TSI")]IAsyncCollector<string> outputEvents,
            ILogger log)
        {
            try
            {
            JObject message = (JObject)JsonConvert.DeserializeObject(Encoding.UTF8.GetString(myEventHubMessage.Body));
            log.LogInformation($"Reading event: {message}");

            // Read values that are replaced or added
            var tsiUpdate = new Dictionary<string, object>();
            foreach (var operation in message["patch"])
            {
                if (operation["op"].ToString() == "replace" || operation["op"].ToString() == "add")
                {
                    //Convert from JSON patch path to a flattened property for TSI
                    //Example input: /Front/Temperature
                    //        output: Front.Temperature
                    string path = operation["path"].ToString().Substring(1);
                    path = path.Replace("/", ".");
                    if (path.Contains("State") | path.Contains("IsOccupied"))
                    {
                        if (bool.Parse(operation["value"].ToString()) == true)
                            tsiUpdate.Add(path, 1);
                        else
                            tsiUpdate.Add(path, 0);
                    }
                    else
                        tsiUpdate.Add(path, operation["value"]);
                }
            }
            // Send an update if updates exist
            if (tsiUpdate.Count > 0)
            {
                tsiUpdate.Add("$dtId", myEventHubMessage.Properties["cloudEvents:subject"]);
                log.LogInformation($"sending to TSI -> {JsonConvert.SerializeObject(tsiUpdate)}");
                await outputEvents.AddAsync(JsonConvert.SerializeObject(tsiUpdate));
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