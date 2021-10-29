# Deploy Azure Resources

This document walks you through steps to deploy the backend Azure resources for the demo.

> NOTE:  this section assumes you have already set up the pre-requisites mentioned on the [home page](/README.md), in particular that you have an Azure Subscription and have set up a PowerShell cloud shell connection.

## Clone repository in Cloud Shell

You will need to clone this repository in your Cloud Shell to run the required deployment scripts:

```powershell
git clone https://github.com/Azure-Samples/azure-digital-twins-unreal-integration
cd azure-digital-twins-unreal-integration
```

## Run deployment Wizard

Run the command below to kick off the wizard that will help you deploy the Azure resources:

> NOTE: The wizard will ask you a few questions that are relevant to the deployment, like desired Azure subscription (in case you have more than one), Azure region and a distinctive name for your project.

```powershell
./deployment/deploy.ps1
```

## Collect output files location

Once the deployment has completed, it will print out the location of some output files you will need moving forward in the demo. The script output will look something like this:

```powershell
Unreal config file path: /home/user/azure-digital-twins-unreal-integration/output/unreal-plugin-config.json
Mock devices config file: /home/user/azure-digital-twins-unreal-integration/output/mock-devices.json

##############################################
##############################################
####                                      ####
####        Deployment Succeeded          ####
####                                      ####
##############################################
##############################################
```

> NOTE: In case you forget to copy the files' location, all output files are located in the `output` folder located at the root of the repository.

## Download config files

To do so, in the cloud shell, click on the icon shown below and choose "Download".

![file download](/media/azure-upload-download.jpg)

In the download box, enter `/azure-digital-twins-unreal-integration/output/mock-devices.json` and click "Download".

Repeat the steps above to also download `/azure-digital-twins-unreal-integration/output/unreal-plugin-config.json`.

Depending on your browser, your files will be downloaded somewhere to your machine.  Note the location as we'll need it later.

Now you are ready to move on with the Unreal demo. Click [here](/README.md#configure-unreal-connections-to-azure) to go back to the main page.
