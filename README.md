# Unreal Engine and Azure Digital Twins integration demo

 The ADT Link plugin and this sample content was developed by WSP in collaboration with Microsoft and Epic Games in order to demonstrate how to integrate [Azure Digital Twins (ADT)](https://docs.microsoft.com/en-us/azure/digital-twins/overview) with the [Unreal Engine](https://www.unrealengine.com/). This sample shows you the "backstage" of the downloadable and playable demo hosted [here](https://epicgames.box.com/s/0zumrf4zf5bzdtbe5ck99uppj5rucz2p). If you just want to see a playable sample of the integration, feel free to walk through that demo. If you want to know how it works and recreate it, read on.

>NOTE:  We are very interested in your feedback related to this sample.  Whether it is feedback about its usefulness, architecture, or if you find a bug, please let us know by filing a github issue [here](https://github.com/Azure-Samples/azure-digital-twins-unreal-integration/issues)

In this sample, you will:

* deploy the proper Azure resources for IoT Hub and ADT.
* use the ADT Link plugin to define sensors of various types in a sample building
* push those sensors and their relationships to an ADT model and twin graph
* hook up simulated versions of those sensors to the Azure IoT Hub and use that data to update the twins with the latest readings
* tour the building virtually and see the sensor data changing in real time

A high level architecture of the sample is shown below.

![high level architecture](media/solution-architecture.jpg)

## What It Does

This documentation will get you set up with an example scene of a WSP office building digital twin, with pre-determined sensors and settings. Going through the sample will inform you how to replicate the results with your own digital twin or IoT sensors.

## What It Does Not Do

At this time, the ADTLink plugin is primarily intended to assist with the creation and publishing of an ADT digital twin from a 3D model in Unreal Engine. If you already have an operational ADT solution, this will not be plug-and-play at this time. Through this guide you will learn how to define your own models in UE and use that to define your new digital twin, but support for existing ADT instances will be limited.

## Prerequisites

To start the process of deploying the demo, you must first work through a few pre-requisites.

### Azure Resources and Simulated IoT Devices

* To deploy the Azure resources, you must have an active Azure subscription in which you have owner permissions. If you do not have an Azure subscription, you can sign up for a free account [here](https://azure.microsoft.com/en-us/free/)
* A [PowerShell Azure Cloud Shell](https://docs.microsoft.com/en-us/azure/cloud-shell/quickstart-powershell)
* [NodeJS](https://nodejs.org/en/download/) - you need NodeJS on your local development machine to run the IoT device simulator

### Unreal Engine Prerequisites

* The ADT Link plugin and its sample content are designed for UE 4.26 or 4.27.

With the pre-requisites installed, you are ready to begin work on the demo

## Deploy the demo solution

### STEP 1: Deploy Azure Infrastructure

As the focus of this sample is primarily on the integration, we've automated most of the setup of the Azure components of the solution. If you want to better understand the components involved on the Azure side, you can walk through the hands-on labs and MS Learn modules.

At a high level, the key Azure components are:

* [Azure IoT Hub](https://azure.microsoft.com/en-us/services/iot-hub/) - this is the primary connection point for IoT devices in the Azure cloud. It ingests the telemetry data from our (simulated) IoT sensors.
* [Azure Digital Twins](https://azure.microsoft.com/en-us/services/digital-twins/) - this is the primary Azure service being demonstrated in this sample. ADT allows you to model the 'real world' and add critical business context, hierarchy, and enriched information to the raw telemetry data ingested from IoT Hub
* [Azure SignalR Service](https://azure.microsoft.com/en-us/services/signalr-service/) - SignalR is a high scale, high performance pub-sub service hosted in Azure. It allows a sender to submit messages in real time to a large number of simultaneous listening applications. In the sample here, we will only have one listener, but for the playable sample demo, we may have many listening
* [Azure Time Series Insights](https://azure.microsoft.com/en-us/services/time-series-insights/) - Time Series Insights is a time-series store, query, and dashboarding service. For this solution, we leverage this as the store and rendering mechanism for the historical data graphs for the sensors
* [Event Grid](https://azure.microsoft.com/en-us/services/event-grid/) and [Azure Functions](https://docs.microsoft.com/en-us/azure/azure-functions/functions-overview) - these components act as the routing and glue between the major components. Event Grid routes messages to the functions in response to events (telemetry received or twin data updated) and the functions perform message transformation and updating.

Follow [these instructions](docs/deploy-azure-resources.md) to deploy the backend Azure services involved. Note that there is a configuration file that will be generated during this process that you will need to download and keep for the next step.

### STEP 2: Configure Unreal Connections to Azure

Following [these instructions](docs/adt-link-plugin-ue.md) will get you set up with the ADT Link plugin for Unreal Engine and walks you through steps required for establishing a connection to ADT and creating virtual sensors in the example scene.

### STEP 3: Simulate Devices

The next step is to simulate device data from our building IoT sensors. To set up the simulated devices, follow the instructions [here](docs/simulate-iot-devices.md).

### STEP 4: View results in the Unreal Engine

After following the three guides above, you should end up with a playable office scene that visualizes live data coming from your own Azure Digital Twin instance. You can then define and deploy your own virtual sensors to customize it to your needs.
