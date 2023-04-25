<# 
.SYNOPSIS 
    Alert on VMs without JIT VM Access enabled
.DESCRIPTION 
    Alert on VMs without JIT VM Access enabled
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  8/23/2022
    Purpose/Change: Initial Script Creation   
#>


$TenantId           = "xxx"
$automationAccount  = "xxx" 
$resourceGroup      = "xxx"
$AttachArr          = @()

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
    "vm_name" = "description"
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

# Create CSV ATtachment
function Get-CSVAttachment 
{
    param
    (
        [Parameter(Mandatory=$true)]
        [array] $Data,
        [Parameter(Mandatory=$true)]
        [string] $Filename
    )

    $DataCSV = ($Data | ConvertTo-CSV -NoTypeInformation) -join [System.Environment]::NewLine
    $EncodedData = [System.Text.Encoding]::ASCII.GetBytes($DataCSV)
    $EncodedB64 = [System.Convert]::ToBase64String($EncodedData)
    
    $attachProps = @{
        "content" = $encodedB64 
        "disposition" = "attachment"
        "filename" = "$filename"
        "type" = "text/csv"
    }

     return $attachProps
}

# Get subscriptions, don't check personal Visual Studio or Citrix subscriptions
$ActiveSubscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object {$_.State -eq "Enabled" -and $_.name -notmatch "Visual Studio" -and $_.name -notmatch "citrix"}    

$VMResultsArr = @()
foreach ($Sub in $ActiveSubscriptions)
{
    Select-AzSubscription -subscription $Sub.Id -TenantId $TenantId
    
    $VMs = Get-AzVM -Status | Select-Object Name,ResourceGroupName,Location,StorageProfile,PowerState
    
    foreach ($VM in $VMs)
    {
        # Skip excluded VMs
        if ($VM.name -notin $ExcludedVMs.Keys -and $VM.ResourceGroupName -notmatch "Databricks-RG" -and $VM.PowerState -eq "VM running")
        {
            $JITCheck = Get-JITCheck -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName -Location $VM.Location -SubscriptionId $Sub.Id

            if ($JITCheck -ne $True)
            {
                # Create custom object
                $VMProps = [ordered]@{
                    VMName                  = $VM.Name
                    ResourceGroupName       = $VM.ResourceGroupName
                    PowerState              = $VM.PowerState
                    Location                = $VM.Location
                    OperatingSystem         = $VM.storageprofile.osdisk.ostype
                    JITConfigured           = $JITCheck
                    Subscription            = $Sub.name
                }

            $VMResultsObj = New-Object -TypeName PSObject -Property $VMProps
            $VMResultsArr += $VMResultsObj
            }
        }    
        Clear-Variable JITCheck
        Clear-Variable VMs
    }
}

# Create Email
$Header = @"
<style>
@charset "UTF-8";
table {font-family:Calibri;border-collapse:collapse;background-color: #f1f1f1}
td
{font-size:1em;border:1px solid #2191ca;padding:5px 5px 5px 5px;}
th
{font-size:1em;border:1px solid #2191ca;text-align:center;padding-top:px;padding-bottom:4px;padding-right:4px;padding-left:4px;background-color:#2191ca ;color:#ffffff;}
</style>
<h2 style="Calibri";> Virutal Machines that are not configured for JIT </h2>
<h3 style="Calibri";> Note: To exclude a VM, add its name to the 'ExcludedVMs' array in the runbook. </h3>

"@

$EmailBody += $header

# If there are no results add 'no data' to array to indicate this
If (!$VMResultsArr)
{
    $VMResultsArr = "[no data]"
    $EmailBody += $UserResultsArr
# Otherwise add the content to the body of the email and also create an attachment
}Else{

    $EmailBody += $VMResultsArr  | ConvertTo-HTML
    $AttachArr += Get-CSVAttachment -data $VMResultsArr -filename "VMs_NoJIT.csv"
}

# Build Excluded UPNs Object
$ExcludedVMArr = @()
Foreach ($ExcludedVM in $ExcludedVMs.GetEnumerator())
{
    $ExcludedVMProps = [Ordered]@{
        VMName = $ExcludedVM.Key
        Description = $ExcludedVM.Value
    }

    $ExcludedVMObj = New-Object -TypeName PSObject -Property $ExcludedVMProps
    $ExcludedVMArr += $ExcludedVMObj

}

# Create attachment for excluded UPNs/Descriptions
$AttachArr += Get-CSVAttachment -data $ExcludedVMArr -filename "Excluded_VMs.csv"

# Send via SendGrid
$params = @{
    ToEmailAddress = "xxx";
    FromEmailAddress = "xxx";
    Subject = "Alert: VMs not configured with JIT - " + (Get-Date -DisplayHint Date);
    Body = $EmailBody;
    Attachments = $AttachArr
}


## Set Context of Runbook and call Set-SendGridMessage runbook and pass params for email
Set-AzContext -SubscriptionId "xxx"

## Call Set-SendGridMessage runbook and pass params for email
Start-AzAutomationRunbook  –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $resourceGroup –Parameters $params