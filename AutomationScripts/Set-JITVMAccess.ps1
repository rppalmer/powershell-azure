<# 
.SYNOPSIS 
    Configure VMs automatically for JIT
.DESCRIPTION 
    Configure VMs automatically for JIT
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  10/21/2022
    Purpose/Change: Initial Script Creation   
#>

$TenantId           = "xxx"

## Connect with Managed Identity
Connect-AzAccount -Identity

# Get a token
$azContext = Get-AzContext
$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
$profileClient = New-Object -TypeName Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient -ArgumentList ($azProfile)
$token = $profileClient.AcquireAccessToken($azContext.Subscription.TenantId)
$authHeader = @{
   'Content-Type'='application/json'
   'Authorization'='Bearer ' + $token.AccessToken
}

# Exclusions
$ExcludedVMs = [ordered]@{
    "VM_1" = "Description"
    "VM_2" = "Description"
}


# Function returns true/false depending on if VM is JIT Configured
function Get-JITCheck {
    param (
        [string]$VMName,
        [string]$ResourceGroupName,
        [string]$SubscriptionId,
        [string]$Location
    )
    
    $Uri = "https://management.azure.com/subscriptions/$($SubscriptionId)/resourceGroups/$($ResourceGroupName)/providers/Microsoft.Security/locations/$($location)/jitNetworkAccessPolicies/default?api-version=2020-01-01"

    try{
        # Get JIT Configuration for specified VM
        $results = Invoke-RestMethod -Headers $authHeader -Uri $Uri -UseBasicParsing -Method Get -ContentType "application/json" -ErrorAction Stop

        # If results not empty loop through each result (could be multiple VMs in the results object). 
        if ($results)
        {
            foreach ($result in $results.properties.virtualmachines)
            {
                # If JIT configured, return true
                if ($VMname -eq ($result.id -split ("/"))[-1])
                {
                    return $true
                }
            }
        }else{
            return $false
        }
    }catch{
        return $false
    }
}

function Set-JITVMAccess {
    param (
        [string]$VMName
        #[string]$OperatingSystem,
        #[string]$SubscriptionId,
        #[string]$Location
    )
    
    $Results = Search-AzGraph -first 1000 -Query "resources | where type =~ 'Microsoft.Compute/VirtualMachines' and name contains '$VMname' | extend OSType=tostring(properties.storageProfile.osDisk.osType)"
    #Write-Host $Results[0]

    $allowedSourceAddressPrefix=@("1.2.3.4/24,2.3.4.5/23")
    if ($Results[0].OSType -eq "Windows")
    {
    Write-Host $Results[0].name "OS is Windows"
    $JitPolicy = (@{
        id=$Results[0].id;
        ports=(@{
            number=3389;
            protocol="*";
            allowedSourceAddressPrefix=$allowedSourceAddressPrefix;
            maxRequestAccessDuration="PT3H"})})
    }
    if ($Results[0].OSType -eq "Linux")
    {
    Write-Host $Results[0].name "OS is Linux"
    $JitPolicy = (@{
        id=$Results[0].id;
        ports=(@{
            number=22;
            protocol="*";
            allowedSourceAddressPrefix=$allowedSourceAddressPrefix;
            maxRequestAccessDuration="PT3H"})})
    }
    $JitPolicyArr=@($JitPolicy)
    Select-AzSubscription -SubscriptionId $Results[0].subscriptionId
    Set-AzJitNetworkAccessPolicy -Kind "Basic" -Location $Results[0].location -Name 'default' -ResourceGroupName $Results[0].resourceGroup -VirtualMachine $JitPolicyArr
}


# Get subscriptions, don't check personal Visual Studio or Citrix subscriptions
$ActiveSubscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object {$_.State -eq "Enabled" -and $_.name -notmatch "Visual Studio" -and $_.name -notmatch "citrix"}    

foreach ($Sub in $ActiveSubscriptions)
{
    Select-AzSubscription -subscription $Sub.Id -TenantId $TenantId
    
    $VMs = Get-AzVM -Status | Select-Object Name,ResourceGroupName,Location,StorageProfile,PowerState
    
    foreach ($VM in $VMs)
    {
        # Skip excluded VMs
        if ($VM.name -notin $ExcludedVMs.Keys -and $VM.ResourceGroupName -notmatch "Databricks-RG" -and $VM.PowerState -eq "VM running")
        {
            # Check state of JIT
            $JITCheck = Get-JITCheck -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName -Location $VM.Location -SubscriptionId $Sub.Id

            # If JIT not configured, configure it
            if ($JITCheck -ne $True)
            {
                Set-JITVMAccess -VMName $VM.Name 

                # we have all the information we need, could skip Search-AzGraph on the Get-JITVMAccess function call
                #Set-JITVMAccess -VMName $VM.Name -Location $VM.Location -OperatingSystem $VM.storageprofile.osdisk.ostype -Subscriptionid $Sub.id

            }
        }    
        Clear-Variable JITCheck
        Clear-Variable VMs
    }
}

