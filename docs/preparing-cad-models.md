# Preparing CAD Models

If you've gone through the setup of the sample scene, you'll know that the ADTLink plugin can automatically detect and place devices (twins) in your scene based on the contents of your Datasmith file. This quick guide will show you how to prepare your own CAD model with the right metadata before exporting it as a Datasmith file.

We will be using Revit in our example below, but any CAD or BIM software that exports to Datasmith will be similar.  This sample file can be downloaded from GitHub [here](/wsp-office-model/)

![SampleRevit](/media/preparing-cad-models/SampleRevit.png "SampleRevit")

There are two metadata keys that the plugin is looking for in an element of your scene.

1) ADT_ModelId
2) ADT_TwinId.

Click on the Manage tab, and open the Project Parameters dialog from the ribbon. Click "Add..."

![AddParameter](/media/preparing-cad-models/AddParameter.png "AddParameter")

In this window you will define a new text parameter by putting "ADT_ModelId" into the "Name" box. Select any categories that this parameter should apply to or select "Check All." Then, click Ok and repeat the process for a new parameter "ADT_TwinId".

![ParamProperties](/media/preparing-cad-models/ParamProperties.png "ParamProperties")

Now if you click on any 3D element in your scene, you can see that they have available properties for our 2 metadata tags. For our sample scene we will select a lighting fixture mesh and type in the values that we know are associated with lighting sensors in our ADT instance.

![MeshData](/media/preparing-cad-models/MeshData.png "MeshData")

Now we can export the 3D view from the Datasmith tab and it would be ready for automatic twin placement in the ADT Setup process.

![ViewExport](/media/preparing-cad-models/ViewExport.png "ViewExport")

Inside Unreal, the imported Datasmith mesh should have the relevant metadata embedded in Asset User Data > Datasmith User Data > Metadata. When using the [ADTLinkSetup utility](./adt-link-plugin-ue.md#create-twin), it should find the various twins in your level when using the "Find Twins in DS" functionality.

![Meta data](/media/preparing-cad-models/Metadata.png)
