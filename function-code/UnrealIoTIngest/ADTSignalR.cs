// Default URL for triggering event grid function in the local environment.
// http://localhost:7071/runtime/webhooks/EventGrid?functionName={functionname}
using System;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Host;
using Microsoft.Azure.EventGrid.Models;
using Microsoft.Azure.WebJobs.Extensions.EventGrid;
using Microsoft.Extensions.Logging;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Azure.WebJobs.Extensions.SignalRService;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace UnrealAzFuncs
{
    public static class ADTSignalR
    {
        [FunctionName("negotiate")]
        public static SignalRConnectionInfo GetSignalRInfo(
            [HttpTrigger(AuthorizationLevel.Anonymous, "post")] HttpRequest req,
            [SignalRConnectionInfo(HubName = "dttelemetry")] SignalRConnectionInfo connectionInfo)
        {
            return connectionInfo;
        }

        [FunctionName("broadcast")]
        public static Task SendMessage(
            [EventGridTrigger] EventGridEvent eventGridEvent,
            [SignalR(HubName = "dttelemetry")] IAsyncCollector<SignalRMessage> signalRMessages,
            ILogger log)
        {
            try
            {
                JObject eventGridData = (JObject)JsonConvert.DeserializeObject(eventGridEvent.Data.ToString());

                //Example eventGridData
                //{"type":1,"target":"newMessage","arguments":[{"TwinId":"thermostat67","data":{"data":{"modelId":"dtmi:foobar:Thermostat;1","patch":[{"value":43,"path":"/Temperature","op":"replace"}]},"contenttype":"application/json","traceparent":"00-e9dd3ac2f37b1a458cd1e2b194c114ab-a48499089c4d1c4c-01"}}]}
                log.LogInformation($"Event grid message: {eventGridData}");

                string twinId = eventGridEvent.Subject.ToString();
                var message = new Dictionary<object, object>
            {
                { "twinId", twinId},
            };

                var data = (JObject)eventGridData["data"];

                var modelId = data["modelId"];
                message.Add("modelId", modelId);

                var patch = data["patch"];

                foreach (var p in patch)
                {
                    message.Add(p["path"], p["value"]);
                }

                log.LogInformation($"SignalR message:  ${JsonConvert.SerializeObject(message)}");

                return signalRMessages.AddAsync(
                    new SignalRMessage
                    {
                        Target = "newMessage",
                        Arguments = new[] { message }
                    });
            }
            catch (Exception e)
            {
                log.LogError(e.ToString());
                throw e;
            }
        }
    }
}
