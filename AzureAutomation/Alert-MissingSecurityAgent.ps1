<# 
.SYNOPSIS 
    Alerts on VMs with missing Security Agents
.DESCRIPTION 
    Alerts on VMs with missing Security Agents
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  6/8/2022
    Purpose/Change: Initial Script Creation   
#>

## Connect with Managed Identity
Connect-AzAccount -Identity

$automationAccount      = "xxx" 
$resourceGroup          = "xxx"
$TenantId               = "xxx"
$Exclusions             = @("vm_name")
$TargetSubscriptions    = Get-AzSubscription | Where-Object {$_.State -eq "Enabled"}

function CheckProvider
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $provider,
        [Parameter(Mandatory=$true, Position=1)]
        [array] $ProviderList
    )

    $GetProviderInfo = $ProviderList | Where-Object {$_.ProviderNamespace -eq $provider}

    If ($GetProviderInfo.RegistrationState -eq "Registered")
    {
        return $true
    }else {
        return $false
    }  

    Clear-Variable GetProviderInfo

}

$VMObjArray = @()
Foreach ($Sub in $TargetSubscriptions)
{
    Select-AzSubscription -SubscriptionId $Sub.Id 

    try{$Providers = Get-AzResourceProvider -ListAvailable}catch{"subscription in a state that prevents provider listing"}
    
    if ($null -ne $Providers)
    {

        $ProviderCheck = CheckProvider -provider "Microsoft.Compute" -ProviderList $Providers
        if ($providerCheck -eq $true)
        {

            # Get non-Citrix VMs that are in a running state
            $VMs = Get-AzVM -status | Where-Object `
            {$_.Name -notin $Exclusions -and `
            $_.ResourceGroupName -notmatch "rg_name"} | Select-Object Name, ResourceGroupName, StorageProfile,PowerState
                
            foreach ($VM in $VMs)
            {
                $VMExtensions = Get-AzVMExtension -VMName $VM.Name -ResourceGroupName $VM.ResourceGroupName 
                
                if ("Rapid7.InsightPlatform" -notin $VMExtensions.Publisher -and $VM.State -eq "VM running")
                {
                                
                    ## Create VM Object
                    $VMProps = [ordered]@{
                        Name            = $VM.Name
                        PowerState      = $VM.PowerState
                        RGName          = $VM.ResourceGroupName
                        OS              = $VM.StorageProfile.OsDisk.OsType
                        Agent           = "InsightVM"
                        Subscription    = $Sub.Name
                    }
                
                    $VMObj = New-Object -TypeName PSObject -Property $VMProps
                    $VMObjArray += $VMObj
                    Clear-Variable VMs
                }
            }
        }
    }
}

## Create Email
$Header = @"
<style>
@charset "UTF-8";
table {font-family:Calibri;border-collapse:collapse;background-color: #f1f1f1}
td
{font-size:1em;border:1px solid #2191ca;padding:5px 5px 5px 5px;}
th
{font-size:1em;border:1px solid #2191ca;text-align:center;padding-top:px;padding-bottom:4px;padding-right:4px;padding-left:4px;background-color:#2191ca ;color:#ffffff;}
</style>
<h2 style="Calibri";> Attention: VMs detected that are missing a security agent </h2>

"@

$EmailBody += $header

## If there are no results add 'no data' to array otherwise add results
IF (!$VMObjArray)
{
    $EmailBody += "<br><h5 style='font-family: Arial, Helvetica, sans-serif;'> [nothing new] </h5>"
}else{
    $EmailBody += $VMObjArray | ConvertTo-HTML
}

## Send via SendGrid
$params = @{
    ToEmailAddress = "xxx";
	AdditionalRecipient1 = "xxx";
    FromEmailAddress = "xxx";
    Subject = "Attention: VMs detected that are missing a security agent - " + (Get-Date -DisplayHint Date);
    Body = $EmailBody;
}

## Set Context of Runbook and call Set-SendGridMessage runbook and pass params for email
$AzureContext = Set-AzContext -SubscriptionId "xxx"
Start-AzAutomationRunbook –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $resourceGroup –Parameters $params

Clear-Variable EmailBody