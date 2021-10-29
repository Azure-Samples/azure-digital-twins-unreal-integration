
# ADT Link Plugin

This guide walks you through the installation and setup of the ADT Link for Unreal Engine plugin in combination with the sample project. The plugin can be used in any project, but following this guide will be extremely beneficial for understanding how the plugin relates to resources in Azure. By the end of this document you will have a sample scene of the WSP office building connected to an Azure Digital Twins instance. Virtual sensors will exist in both environments and will stay in sync once the sensor data is activated in a later stage.

There is a pre-compiled demo using this sample content available for download [here](https://epicgames.box.com/s/0zumrf4zf5bzdtbe5ck99uppj5rucz2p). This is the end result you should expect after walking through the steps outlined below.

## Installing the Plugin and Project

### The Plugin

The "ADTLink for Unreal Engine" plugin is the main piece of technology driving this digital twin experience. If you don't already have it, you'll need to download it from the Unreal Engine Marketplace [here](https://www.unrealengine.com/marketplace/en-US/product/adtlink-for-unreal-engine). Once you add it to your account, you must "Install to Engine", selecting either 4.26 or 4.27.  It can be enabled in any project to connect the scene with a live ADT instance in the cloud. The main components of this plugin are:

1. The ability to send twin model data into ADT and subscribe to a SignalR feed.
2. An editor utility widget that guides the user through the management of the digital twin.

![Marketplace plugin](/media/adt-link-plugin-ue/MarketplacePlugin.png)

### The Project

For the sample project, you can get it for free on the Unreal Engine Marketplace [here](https://www.unrealengine.com/marketplace/en-US/product/adtlink-for-unreal-engine-sample). Once it is added to your account, you must "Create Project" and then open it either from your Library in the Launcher, or from the folder directory. The sample project relies on the plugin being installed to your engine, so make sure you complete that step first before opening it.

To showcase the general workflow and capabilities, the sample project uses the ADT Link plugin to connect to the live ADT sensors that you set up [in the previous step](./deploy-azure-resources.md).  The project contains the following components that you can dig into and explore:

1. A high resolution point cloud of the WSP office
2. An imported Datasmith model of the WSP office, for reference
3. A sleek UMG-based UI for navigating the scene and reading live data
4. Particle effects and character animations for certain data types
5. Examples of custom device models

![Marketplace Sample](/media/adt-link-plugin-ue/MarketplaceSample.png)

# Setting Up a Digital Twin - The Sample Project

Open the sample project. We provide a sample level that already has a Datasmith scene that correlates with the sensors being set up in this guide. It's called "SampleLevel" and is located in Content/WspOfficeDemo/Level. Double-click to open it.

![StartupLevel](/media/adt-link-plugin-ue/StartupLevel.png "StartupLevel")

![StartupLevel_View](/media/adt-link-plugin-ue/StartupLevel_View.png "StartupLevel_View")

## Connecting to Azure Digital Twin

Accessing live data and devices from ADT is all handled through the AdtLink plugin, but the initial connection and sensor setup must be configured. Luckily we provide a utility with the plugin that will help you do this.

To access it, you need to make sure you have both "Show Plugin Content" and "Show Engine Content" enabled in your Content Browser settings. If the AdtLink plugin is enabled, you should see an “AdtLink Content” folder in your list of sources. If you don’t see this list, click on the Sources icon next to Filters.

![AdtLink_Content](/media/adt-link-plugin-ue/AdtLink_Content.png "AdtLink_Content")

You’ll find a Blueprint utility called “BP_AdtLinkSetup” in the AdtLink Content/AdtLink/Utilities folder. Right click on this widget blueprint and select Run Editor Utility Widget. A user interface window will appear on top of the editor.

![AdtLink_Utility_Run](/media/adt-link-plugin-ue/AdtLink_Utility_Run.png "AdtLink_Utility_Run")

![Utility_Connection_Default](/media/adt-link-plugin-ue/Utility_Connection_Default.png "Utility_Connection_Default")

The flow of this interface goes like this:

1. Connection - Establishing the communicator Blueprint
2. Create Model - Uploading our sensor types to ADT
3. Create Twin - Create our virtual sensors in UE and register their twins in ADT

## Connection

To start, you will choose “Spawn New Communicator” in the Connection menu. This adds a Blueprint actor of type “BP_ADTCommunicator” into your scene and you should see a “Communicator found” message if it succeeded. If you’re working in a level that already has this blueprint, just click “Find Communicator in Level” instead.

![Utility_SpawnCommunicator](/media/adt-link-plugin-ue/Utility_SpawnCommunicator.png "Utility_SpawnCommunicator")

To establish a connection to a live instance of Azure Digital Twins via the Communicator, there are several parameters required. These parameters can be typed in manually, but the easiest method is to “Load Configuration File” and use the “unreal-plugin-config.json” file you created in the [initial ADT setup.](./deploy-azure-resources.md#download-config-files) Once you click on “Validate Connection”, it should light up green and print successful results to the log if the configuration is correct and your ADT instance is operational.

![Utility_LoadConfiguration](/media/adt-link-plugin-ue/Utility_LoadConfiguration.png "Utility_LoadConfiguration")

![Utility_ValidateConnection](/media/adt-link-plugin-ue/Utility_ValidateConnection.png "Utility_ValidateConnection")

## Create Models

Azure Digital Twins uses the concept of “models” to represent the entities that you need to replicate from the physical world to the digital. A model can be used to define a device or sensor, but can also be used to define broader concepts such as a room, a floor, a building, or a capability _within_ another model. Any data we want to get from our digital twin must first be defined inside Unreal Engine as a Blueprint, and then uploaded to ADT.

For the purposes of this sample we have already created Model Blueprints that correspond with the sample devices provided. When you're ready to create your own models later you can follow [this guide](./create-custom-models.md).

In the AdtLink plugin we’ve predefined 8 models using the [Real Estate Core ontology](https://github.com/Azure/opendigitaltwins-building), which is a good starting place for typical AECO models:

* Building
* Level
* Room
* Space
* Capability
* Sensor
* Temperature Sensor
* Air Temperature Sensor

These are found in various sub-folders under AdtLinkContent/AdtLink/ModelBP/REC.
In this image, we are using a filter for "Blueprint Class" to only show the Blueprint assets.

![REC_Models](/media/adt-link-plugin-ue/REC_Models.png "REC_Models")

Some of these models “extend” others. For example, the Temperature Sensor model is an extension of the base model Sensor. And Sensor has a variety of Capabilities within it. This is important to understand in the next step because you cannot upload and create a model if the model it extends isn’t already there.

Inside the sample project content we’ve also extended Sensor, Capability, and Space to create 5 custom WSP models:

* WSP Room
* WSP HVAC Sensor
* WSP Lighting Sensor
* WSP Occupancy Sensor
* WSP Temperature Sensor

These can be found in sub-folders under Content/WspOfficeDemo/Blueprint/RECExtended.
In this image, we are using a filter for "Blueprint Class" to only show the Blueprint assets.

![REC_Extended](/media/adt-link-plugin-ue/REC_Extended.png "REC_Extended")

### Uploading the Models

In the “Create Model” menu, you can see the three steps to the left:

1. Select Model BP in Content Browser
2. Press “Convert to JSON”
3. Press “Upload to ADT”

Upload your first model by navigating to AdtLink Content/AdtLink/ModelBP/REC/Space and selecting “BP_Space.” Then click “Convert to JSON”, which should populate the text box with the converted JSON data contained in the Blueprint. Press “Upload to ADT” to send it to the ADT instance. Watch the Log to make sure there aren’t any errors.

![Utility_UploadToADT](/media/adt-link-plugin-ue/Utility_UploadToADT.png "Utility_UploadToADT")

Assuming the first model works, proceed to convert and upload the other models in this exact order:

From ADTLink Content/AdtLink/ModelBP/**REC**/...:

1. BP_Space (_done)_
2. BP_Capability
3. BP_Sensor

From /Content/WspOfficeDemo/Blueprint/**RECExtended**/...:

4. BP_WspHvacSensor
5. BP_WspLightingSensor
6. BP_WspOccupancySensor
7. BP_WspTemperatureSensor
8. BP_WSPRoom

After you’ve finished uploading the models, you can head to the “Edit Model” menu to synchronize with ADT and see what models are living up there. You can “Edit” each model, but for any substantial changes you should delete it and upload a new version.

## Create Twin

The “models” that now reside on ADT define what type of entities and sensors exist in your digital twin, and the “twins” that we will now create are the specific instances of each entity that will be reflected in UE.

There are two ways to create twins:

1. Detecting twins from a Datasmith import
2. Manually creating a twin

For this example project we will only be focusing on the first option. The Datasmith model that exists in the SampleLevel contains a few meshes with ADT-specific metadata for “ModelID” and “TwinID” that were originally defined in Revit.

In the Create Twin window, there is a button for “Find Twins in DS”. Clicking on this will detect any twins present in our scene and should populate the list with the various Twin IDs and their Model IDs. The utility also associates them with the appropriate ModelBP’s we uploaded earlier. You can change the Model ID or Twin ID to a different type if there’s ever an error.

![Utility_FindTwins](/media/adt-link-plugin-ue/Utility_FindTwins.png "Utility_FindTwins")

Now that they are detected and valid, we will create new Blueprint Actors in our scene for each one. Click the checkbox above the right-hand column to highlight all the Twins. You can also select or deselect by clicking on each one individually. Then press “Create Selected Twins”.

![Utility_SelectTwins](/media/adt-link-plugin-ue/Utility_SelectTwins.png "Utility_SelectTwins")

The Log will populate with the various twins being spawned and synchronized in both UE and ADT. In your World Outliner you should now notice that there are various Blueprint actors such as “lightingsensor2” and “occupancysensor1” attached to their respective 3D meshes. Each of these have an ADT Twin Component that brokers the connection to ADT via the Communicator we set up earlier.

![Twin_Details](/media/adt-link-plugin-ue/Twin_Details.png "Twin_Details")

If these twins need editing for any reason, there is an “Edit Twin” window back in the utility. Here you can click the “Edit” button next to any active twin and see or modify its properties. If you need to add or remove any properties, you should delete the twin from ADT and re-upload it through the utility.

![Utility_EditTwins](/media/adt-link-plugin-ue/Utility_EditTwins.png "Utility_EditTwins")

![Utility_EditTwinProperties](/media/adt-link-plugin-ue/Utility_EditTwinProperties.png "Utility_EditTwinProperties")

## Room Sizes and Relationships

The sample scene contains a model type for "Room" which has twins throughout the scene like ConferenceRoom, MediumWorkspace, LargeWorkspace, etc. These room twins contain various sensors within them, but the relationships and 3D bounds weren't automatically established through the setup utility. Let's do that now.

### Resizing a Room

First, we're going to resize the room "devices" that were spawned. This is important for the visual effects in the final app. Select a room. You will see that each room is attached to a mesh of the floor.

![Room Select](/media/adt-link-plugin-ue/RoomSelect.png)

![Room Selected](/media/adt-link-plugin-ue/RoomSelected.png)

There is a custom function called "Set Parent Size" in the "Space" section of each actor's details that will scale it to the proportions of the floor mesh. Click this button.

![Room Size](/media/adt-link-plugin-ue/RoomSize.png)

![Room Sized](/media/adt-link-plugin-ue/RoomResized.png)

To set the height, change the Z value in the Size parameter or drag the blue diamond gizmo hovering in the corner. You will need to click "Update Size" to finalize the new shape and bounds. Then, click the button for "Update Cube Size". This will propagate the room dimensions to the mesh used for colored visuals in the final app.

![Room Cube](/media/adt-link-plugin-ue/RoomCube.png)

Repeat this for the other rooms in the scene.

### Establishing Relationships

To tell ADT that certain rooms contain certain devices, we need to do a little work back in the AdtLinkSetup Utility widget we previously launched. Go to the Edit Twin tab and click the Edit button next to your room of choice, and go to the "Relationships" tab on the right.

![Room Edit](/media/adt-link-plugin-ue/RoomEdit.png)

![Edit Twin Relationships](/media/adt-link-plugin-ue/EditTwinRel.png)

There is a section in the lower half of the window called "Create Relationships." Use the first dropdown box to select the type of relationship we're establishing, which is "hasCapability" in this case. Click the "Select Overlapping" button to precisely grab only the twins that are inside our resized room. Then press "Add Selected" to create a new relationship with those twins.

![Room Relationship](/media/adt-link-plugin-ue/RoomRelationship.png)

Now those active relationships should appear in the section above. You can always add or remove relationships at any time, and they will propagate up to your ADT instance as well.

![Room Active Relationships](/media/adt-link-plugin-ue/RoomActiveRel.png)

Repeat this with any remaining rooms.

## Next Steps - Simulating Devices

If everything was successful, you should now have a level with the WSP office and a handful of sensor Blueprints with a valid connection to Azure Digital Twins. However, the data coming from our ADT instance is currently static and relatively meaningless. To emulate live sensors and visualize their effects in UE, you'll move on to the next step and set up [Mock Devices.](./simulate-iot-devices.md)

## Continue In Your Own Project

### Enable the plugin

Once you're comfortable with the sample project, you can use the ADT Link plugin in any UE project of your own. We recommend starting a project from the "Architecture, Engineering, and Construction" category. With your project open, enable the ADT Link plugin by going to Edit > Plugins and searching for it. Also verify that the Datasmith plugin is enabled. If you're deriving your project from the sample dataset, you'll also need the LiDAR Point Cloud plugin and Sun Position Calculator plugin. This may require a restart for your project.

![EditPlugins](/media/adt-link-plugin-ue/EditPlugins.png "Edit Plugins")

![AdtLink_Plugin](/media/adt-link-plugin-ue/AdtLink_Plugin.PNG "AdtLink_Plugin")

![Datasmith_Plugin](/media/adt-link-plugin-ue/Datasmith_Plugin.PNG "Datasmith_Plugin")

![LidarPlugin](/media/adt-link-plugin-ue/LidarPlugin.png "LidarPlugin")

![SunPosition_Plugin](/media/adt-link-plugin-ue/SunPosition_Plugin.png "SunPositionPlugin")

### Building Your Own Content

To define your own custom models for your sensors or other twins, follow [this guide](./create-custom-models.md).

To prepare your CAD model for automatic twin placement during setup, follow [this guide](./preparing-cad-models).

### Connecting to ADT

In order to leverage this plugin you will need to set up Azure resources as outlined [in this documentation](deploy-azure-resources.md) and use the generated configuration file; at this time it is not plug-and-play with any existing ADT instance. If you need to customize the various Azure resources for your unique situation, the deployment source code is available on this repo. You are also responsible for managing your own device connections into IoT Hub.
