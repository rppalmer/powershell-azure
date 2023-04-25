<# 
.SYNOPSIS 
    Alerts on VMs with missing PatchGroup tag
.DESCRIPTION 
    Alerts on VMs with missing PatchGroup tag
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  6/15/2022
    Purpose/Change: Updated provider check to reduce errors
#>

## Connect with Managed Identity
Connect-AzAccount -Identity

$automationAccount  = "xxx" 
$resourceGroup      = "xxx"
$Exceptions         = @("vmname")
$VMObjArray = @()

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

Foreach ($Sub in (Get-AzSubscription | Where-Object {$_.state -eq "Enabled"}))
{
    Select-AzSubscription -SubscriptionId $Sub.Id | Out-Null

    try{$Providers = Get-AzResourceProvider -ListAvailable}catch{"subscription in a state that prevents provider listing"}
    
    if ($null -ne $Providers)
    {

        $ProviderCheck = CheckProvider -provider "Microsoft.Compute" -ProviderList $Providers
        if ($providerCheck -eq $true)
        {

            $NICs = Get-AzNetworkInterface

            ## Get non-Citrix VMs that are in a running state
            $VMs = Get-AzVM -status | Where-Object {$_.PowerState -match "VM Running" `
            -and $_.Name -notmatch "vm_name" `
            -and $_.ResourceGroupName -notmatch "rg_name*" `
            -and $_.Name -notin $Exceptions}
            
            ## Find all VMs that don't have the PatchGroup tag
            foreach ($VM in $VMs)
            {
                if ("PatchGroup" -notin $VM.tags.keys)
                {
                        
                    Write-Output "[!] $($VM.name) is missing the PatchGroup tag"
                                
                    ## Correlate network adapter
                    $VMNic = $NICs | Where-Object {$_.id -eq $VM.NetworkProfile.NetworkInterfaces.id}

                    ## Create VM Object
                    $VMProps = [ordered]@{
                        Name            = $VM.Name
                        PowerState      = $VM.PowerState
                        RGName          = $VM.ResourceGroupName
                        ipAddress       = $VMNic.IpConfigurations.privateipaddress
                        OS              = $VM.StorageProfile.OsDisk.OsType
                        Subscription    = $Sub.Name
                    }
                
                    $VMObj = New-Object -TypeName PSObject -Property $VMProps
                    $VMObjArray += $VMObj
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
<h2 style="Calibri";> Attention: VMs detected that do not have a "PatchGroup" tag </h2>
<h4 style="Calibri";> Filter: Powered-on Windows or Linux machines that are not in Citrix resource groups </h4>

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
    ToEmailAddress = "alert-security@hpfc.com";
	AdditionalRecipient1 = "itinfrastructureteam@homepointfinancial.com";
    FromEmailAddress = "azurereports@homepointfinancial.com";
    Subject = "Attention: VMs detected that do not have a 'PatchGroup' tag - " + (Get-Date -DisplayHint Date);
    Body = $EmailBody;
}

## Set Context of Runbook and call Set-SendGridMessage runbook and pass params for email
$AzureContext = Set-AzContext -SubscriptionId "xxx"
Start-AzAutomationRunbook –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $resourceGroup –Parameters $params