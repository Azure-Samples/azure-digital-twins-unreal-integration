$root_path = Split-Path $PSScriptRoot -Parent

#region functions
function New-Password {
    param(
        [int] $length = 15
    )

    $punc = 46..46
    $digits = 48..57
    $lcLetters = 65..90
    $ucLetters = 97..122
    $password = `
        [char](Get-Random -Count 1 -InputObject ($lcLetters)) + `
        [char](Get-Random -Count 1 -InputObject ($ucLetters)) + `
        [char](Get-Random -Count 1 -InputObject ($digits)) + `
        [char](Get-Random -Count 1 -InputObject ($punc))
    $password += get-random -Count ($length - 4) `
        -InputObject ($punc + $digits + $lcLetters + $ucLetters) |`
        ForEach-Object -begin { $aa = $null } -process { $aa += [char] $_ } -end { $aa }

    return $password
}
function Get-EnvironmentHash {
    param(
        [int] $hash_length = 8
    )
    $env_hash = (New-Guid).Guid.Replace('-', '').Substring(0, $hash_length).ToLower()

    return $env_hash
}

function Get-ResourceProviderLocations {
    param(
        [string] $provider,
        [string] $typeName
    )

    $providers = $(az provider show --namespace $provider | ConvertFrom-Json)
    $resourceType = $providers.ResourceTypes | Where-Object { $_.ResourceType -eq $typeName } | Sort-Object -Property locations

    return $resourceType.locations
}

function Set-EnvironmentHash {
    param(
        [int] $hash_length = 4
    )
    $script:env_hash = Get-EnvironmentHash -hash_length $hash_length
}

function Read-CliVersion {
    param (
        [version]$min_version = "2.21"
    )

    $az_version = az version | ConvertFrom-Json
    [version]$cli_version = $az_version.'azure-cli'

    Write-Host
    Write-Host "Verifying your Azure CLI installation version..."
    Start-Sleep -Milliseconds 500

    if ($min_version -gt $cli_version) {
        Write-Host
        Write-Host "You are currently using the Azure CLI version $($cli_version) and this wizard requires version $($min_version) or later. You can update your CLI installation with 'az upgrade' and come back at a later time."

        return $false
    }
    else {
        Write-Host
        Write-Host "Great! You are using a supported Azure CLI version."

        return $true
    }
}

function Read-CliExtensionVersion {
    param(
        [string]$name,
        [version]$min_version,
        [bool]$auto_update = $true
    )

    $az_version = az version | ConvertFrom-Json -Depth 5
    [version]$extension_version = $az_version.extensions.$name

    Write-Host
    Write-Host "Verifying '$name' extension version..."
    Start-Sleep -Milliseconds 500

    if ($null -eq $extension_version) {
        Write-Host
        Write-Host "You currently don't have the '$name' CLI extension. Installing it now..."
        az extension add --name $name

        return $true
    }
    elseif ($min_version -gt $extension_version) {
        
        Write-Host
        Write-Host "You are currently using the version $($extension_version) of the extension '$($name)' and this wizard requires version $($min_version) or later."

        if ($auto_update) {
            $update = Get-InputSelection `
                -text "Do you want to update it now?" `
                -options @("Yes", "No") `
                -default_index 1
            
            if ($update -eq 1) {
                az extension update -n $name
    
                return $true
            }
            else {
                Write-Host
                Write-Host "You can find more details to manage extensions with Azure CLI here. https://docs.microsoft.com/en-us/cli/azure/azure-cli-extensions-overview"
    
                return $false
            }
        }
        else {
            Write-Host
            Write-Host "You can find more details to manage extensions with Azure CLI here. https://docs.microsoft.com/en-us/cli/azure/azure-cli-extensions-overview"

            return $false
        }
    }
    elseif ($min_version -le $extension_version) {
        Write-Host
        Write-Host "Great! You are using a supported version of the extension '$name'."

        return $true
    }
    else {
        Write-Host
        Write-Host "Unrecognized CLI extension output. Exiting now."

        return $false
    }
}

function Set-AzureAccount {
    param()

    Write-Host
    Write-Host "Retrieving your current Azure subscription..."
    Start-Sleep -Milliseconds 500

    $account = az account show | ConvertFrom-Json

    $option = Get-InputSelection `
        -options @("Yes", "No. I want to use a different subscription") `
        -text "You are currently using the Azure subscription '$($account.name)'. Do you want to keep using it?" `
        -default_index 1
    
    if ($option -eq 2) {
        $accounts = az account list | ConvertFrom-Json | Sort-Object -Property name

        $account_list = $accounts | Select-Object -Property @{ label="displayName"; expression={ "$($_.name): $($_.id)" } }
        $option = Get-InputSelection `
            -options $account_list.displayName `
            -text "Choose a subscription to use from this list (using its Index):" `
            -separator "`r`n`r`n"

        $account = $accounts[$option - 1]

        Write-Host "Switching to Azure subscription '$($account.name)' with id '$($account.id)'."
        az account set -s $account.id
    }
}
function Set-ProjectName {
    param()

    $script:project_name = $null
    $script:resource_group_name = $null
    $script:create_resource_group = $false
    $first = $true

    while ([string]::IsNullOrEmpty($script:project_name) -or ($script:project_name -notmatch "^[a-z0-9-_]{4,14}[a-z0-9]{1}$")) {
        if ($first -eq $false) {
            Write-Host "Use alphanumeric characters, hyphens and underscores, between 5 and 15 characters long"
        }
        else {
            Write-Host
            Write-Host "Provide a name that describes your project. This will be used to create the resource group and the deployment resources."
            $first = $false
        }
        $script:project_name = Read-Host -Prompt ">"

        $script:resource_group_name = "$($script:project_name)-rg"
        $resourceGroup = az group list | ConvertFrom-Json | Where-Object { $_.name -eq $script:resource_group_name }
        if (!$resourceGroup) {
            $script:create_resource_group = $true
        }
        else {
            $script:create_resource_group = $false
        }
    }
}

function Get-InputSelection {
    param(
        [array] $options,
        $text,
        $separator = "`r`n",
        $default_index = $null
    )

    Write-Host
    Write-Host $text -Separator "`r`n`r`n"
    $indexed_options = @()
    for ($index = 0; $index -lt $options.Count; $index++) {
        $indexed_options += ("$($index + 1): $($options[$index])")
    }

    Write-Host $indexed_options -Separator $separator

    if (!$default_index) {
        $prompt = ">"
    }
    else {
        $prompt = "> $default_index"
    }

    while ($true) {
        $option = Read-Host -Prompt $prompt
        try {
            if (!!$default_index -and !$option)  {
                $option = $default_index
                break
            }
            elseif ([int] $option -ge 1 -and [int] $option -le $options.Count) {
                break
            }
        }
        catch {
            Write-Host "Invalid index '$($option)' provided."
        }

        Write-Host
        Write-Host "Choose from the list using an index between 1 and $($options.Count)."
    }

    return $option
}

function New-IoTMockDevices {
    param (
        [string]$resource_group,
        [string]$hub_name,
        [string]$template_file,
        [string]$output_file
    )

    Write-Host
    Write-Host "Looking at devices in IoT hub '$($hub_name)' from resource group '$($resource_group)'"

    $iot_hub = az iot hub show -g $resource_group -n $hub_name | ConvertFrom-Json
    $iot_hub_devices = az iot hub device-identity list -g $resource_group -n $hub_name |ConvertFrom-Json

    $mock_devices = Get-Content -Path $template_file | ConvertFrom-Json -Depth 10
    for ($i = 0; $i -lt $mock_devices.devices.Count; $i++) {
        if ($mock_devices.devices[$i].configuration._kind -eq "hub") {
            $device = $iot_hub_devices | Where-Object { $_.deviceId -eq $mock_devices.devices[$i].configuration.deviceId }

            if (!$device) {
                Write-Host
                Write-Host "Creating mock device '$($mock_devices.devices[$i].configuration.deviceId)' in IoT hub"
                $device = az iot hub device-identity create `
                    -g $resource_group `
                    -n $hub_name `
                    -d $mock_devices.devices[$i].configuration.deviceId | ConvertFrom-Json

                if (!!$device.authentication.symmetricKey.primaryKey) {
                    $device_conn_string = "HostName=$($iot_hub.properties.hostName);DeviceId=$($device.deviceId);SharedAccessKey=$($device.authentication.symmetricKey.primaryKey)"
                }
                else {
                    Write-Warning "Unable to create connection string for device '$($device.deviceId)'"
                }
            }
            else {
                Write-Host
                Write-Host "Retrieving symmetric key for device '$($mock_devices.devices[$i].configuration.deviceId)' from IoT hub"
                $device_conn_string = az iot hub device-identity connection-string show `
                    -g $resource_group `
                    -n $hub_name `
                    -d $device.deviceId `
                    --query connectionString -o tsv
            }

            $mock_devices.devices[$i].configuration.connectionString = $device_conn_string
        }
    }

    Write-Host
    Write-Host "Writing mock devices' configuration"
    Set-Content -Path $output_file -Value (ConvertTo-Json $mock_devices -Depth 10)
}
#endregion

function New-Deployment() {

    # Set environment's unique hash
    Set-EnvironmentHash -hash_length 8

    #region greetings
    Write-Host
    Write-Host "################################################"
    Write-Host "################################################"
    Write-Host "####                                        ####"
    Write-Host "#### Unreal Engine and Azure Digital Twins  ####"
    Write-Host "####           integration demo             ####"
    Write-Host "####                                        ####"
    Write-Host "################################################"
    Write-Host "################################################"

    Start-Sleep -Milliseconds 1500

    Write-Host
    Write-Host "Welcome to the Unreal Engine and Azure Digital Twins (ADT) integration demo. This deployment script will help you deploy a sandbox environment in your Azure subscription. This demo leverages the ADT Link plugin, that was created along with this sample demo by WSP in collaboration with Microsoft and Epic Games, in order to demonstrate how to integrate Azure Digital Twins with the Unreal Engine."
    Write-Host
    Write-Host "Press Enter to continue."
    Read-Host
    #endregion

    #region validate CLI version
    $cli_valid = Read-CliVersion -min_version "2.28"
    if (!$cli_valid) {
        return $null
    }

    $iot_ext_valid = Read-CliExtensionVersion -min_version "0.11.0" -name 'azure-iot' -auto_update $true
    if (!$iot_ext_valid) {
        return $null
    }
    #endregion

    #region set azure susbcription and resource providers
    Set-AzureAccount

    Write-Host
    Write-Host "Registering ADT resource provider in your subscription"
    az provider register --namespace 'Microsoft.DigitalTwins'
    #endregion

    #region region
    $adt_locations = Get-ResourceProviderLocations -provider 'Microsoft.DigitalTwins' -typeName 'DigitalTwinsInstances'
    $tsi_locations = Get-ResourceProviderLocations -provider 'Microsoft.TimeSeriesInsights' -typeName 'environments'
    $locations = $adt_locations | Where-Object { $tsi_locations -contains $_ } | Sort-Object

    $option = Get-InputSelection `
        -options $locations `
        -text "Choose a region for your deployment from this list (using its Index):"

    $script:location = $locations[$option - 1].Replace(' ', '').ToLower()
    #endregion

    #region resource group
    Set-ProjectName

    Write-Host
    if ($script:create_resource_group) {
        Write-Host "Creating resource group '$script:resource_group_name'..."
        $null = az group create -n $script:resource_group_name --location $script:location
    }
    else {
        Write-Host "Resource group '$script:resource_group_name' already exists in current subscription."
    }
    #endregion

    #region AAD
    Write-Host
    Write-Host "Collecting current user information"
    # JH 2022-08-09
	# https://docs.microsoft.com/en-us/cli/azure/microsoft-graph-migration#breaking-changes
    $script:userId = az ad signed-in-user show --query id -o tsv

    $script:appRegName = "$($script:resource_group_name)-$($script:env_hash)"

    Write-Host
    Write-Host "Creating app registration manifest"
    $manifest = @(
        @{
            "resourceAppId" = "0b07f429-9f4b-4714-9392-cc5e8e80c8b0"
            "resourceAccess" = @(
                @{
                    "id" = "4589bd03-58cb-4e6c-b17f-b580e39652f8"
                    "type" = "Scope"
                }
            )
        }
    )
    Set-Content -Path "manifest.json" -Value (ConvertTo-Json $manifest -Depth 5)

    Write-Host
    Write-Host "Creating app registration '$($script:appRegName)' in Azure Active Directory"
	# JH 2022-08-09
    # https://docs.microsoft.com/en-us/cli/azure/microsoft-graph-migration#breaking-changes
    $script:appReg = az ad app create `
        --display-name $script:appRegName `
        --sign-in-audience AzureADMultipleOrgs `
        --public-client-redirect-uris http://localhost `
        --web-redirect-uris http://localhost `
        --is-fallback-public-client $true `
        --required-resource-accesses "@manifest.json" | ConvertFrom-Json

    $found = $false
    $count = 3
    while (!$found -and $count -gt 0) {
        $appReg = az ad app show --id $($script:appReg.appId) | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($appReg.appId) {
            $found = $true
        }
        else {
            Start-Sleep -Milliseconds 1000
            $count = $count - 1
        }
    }

    Write-Host
    Write-Host "Creating service principal associated with the app registration"
    Start-Sleep -Seconds 10
    $script:service_ppal = az ad sp create --id $script:appReg.appid | ConvertFrom-Json

    Write-Host
    Write-Host "Creating client secret for app registration"
    Start-Sleep -Seconds 10
    $script:appRegSecret = az ad app credential reset --id $script:appReg.appId --append | ConvertFrom-Json
    #endregion

    #region create deployment
    $template = Join-Path $root_path "deployment" "azuredeploy.bicep"
    $parameters = Join-Path $root_path "deployment" "azuredeploy.parameters.json"
    $deployment_id = "$($script:project_name)-$($script:env_hash)"

    # JH 2022-08-09
    # https://docs.microsoft.com/en-us/cli/azure/microsoft-graph-migration#breaking-changes
    $template_parameters = @{
        "unique"                   = @{ "value" = $script:env_hash }
        "userId"                   = @{ "value" = $script:userId }
        "appRegId"                 = @{ "value" = $script:appReg.appId }
        "appRegPassword"           = @{ "value" = $script:appRegSecret.password }
        "servicePrincipalObjectId" = @{ "value" = $script:service_ppal.id }
        "tenantId"                 = @{ "value" = $script:appRegSecret.tenant }
        "repoOrgName"              = @{ "value" = "Azure-Samples" }
        "repoName"                 = @{ "value" = "azure-digital-twins-unreal-integration" }
        "repoBranchName"           = @{ "value" = $(git rev-parse --abbrev-ref HEAD) }
    }
    Set-Content -Path $parameters -Value (ConvertTo-Json $template_parameters -Depth 5)

    Write-Host
    Write-Host "Creating resource group deployment with id '$deployment_id'"
    
    $script:deployment_output = az deployment group create `
        --resource-group $script:resource_group_name `
        --name $deployment_id `
        --mode Incremental `
        --template-file $template `
        --parameters $parameters | ConvertFrom-Json
    
    if (!$script:deployment_output) {
        throw "Something went wrong with the resource group deployment. Ending script."        
    }

    $important_info = az deployment group show `
        -g $script:resource_group_name `
        -n $deployment_id `
        --query properties.outputs.importantInfo.value
    
    $webAppHostname = az deployment group show `
        -g $script:resource_group_name `
        -n $deployment_id `
        --query properties.outputs.webAppUrl.value `
        -o tsv
    Write-Host
    Write-Host "Rsrouce group deployment completed."
    #endregion

    #region create unreal config file
    $unreal_file = Join-Path $root_path "output" "unreal-plugin-config.json"

    Write-Host
    Write-Host "Creating unreal config file"
    Set-Content -Path $unreal_file -Value ($important_info)
    #endregion

    #region mock devices config file
    $devices_template = Join-Path $root_path "devices" "mock-devices-template.json"
    $devices_file = Join-Path $root_path "output" "mock-devices.json"
    $script:iot_hub_name = ($important_info | ConvertFrom-Json).iotHubName

    New-IoTMockDevices `
        -resource_group $script:resource_group_name `
        -hub_name $script:iot_hub_name `
        -template_file $devices_template `
        -output_file $devices_file
    #endregion

    Write-Host
    Write-Host -ForegroundColor Yellow "Resoruce Group: $($script:resource_group_name)"
    Write-Host -ForegroundColor Yellow "Unreal config file path: $((Get-ChildItem -Path $unreal_file).FullName)"
    Write-Host -ForegroundColor Yellow "Mock devices config file: $((Get-ChildItem -Path $devices_file).FullName)"

    Write-Host
    Write-Host -ForegroundColor Green "##############################################"
    Write-Host -ForegroundColor Green "##############################################"
    Write-Host -ForegroundColor Green "####                                      ####"
    Write-Host -ForegroundColor Green "####        Deployment Succeeded          ####"
    Write-Host -ForegroundColor Green "####                                      ####"
    Write-Host -ForegroundColor Green "##############################################"
    Write-Host -ForegroundColor Green "##############################################"
    Write-Host
}

New-Deployment
