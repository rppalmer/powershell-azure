<# 
.SYNOPSIS 
    List storage account containers with anonymous access
.DESCRIPTION 
    Queries storage accounts in all subscriptions and alerts
    if any are publicly accessible.
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  7/2/2021
    Purpose/Change: Initial script development 
#> 

$automationAccount      = "xxx" 
$aaResourceGroup        = "xxx"
$allActiveSubscriptions = Get-AzSubscription | Where-Object {$_.State -eq "Enabled"}    

# log start time of script
$ScriptStartTime = (Get-Date)                                                                           

# Connect with Managed Identity
Connect-AzAccount -Identity

# Set to true to send alert
$SendMailCheck = $False  

# Name of the storage account as it appears in the Azure Portal
$Exceptions = @("storageAccountName")

# Log Function
Function logFunction
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $message,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $logName
    )
    
    $logFilePath = "C:\ScriptLogs\Alert-AnonymousStorage\"
    
    if ( -not (Test-path $logFilePath))
    {
        New-Item -Type directory $logFilePath
    }
    
    $timestamp = Get-Date -UFormat "%Y%m%dT%I%M%S"
    "$timestamp : $message" | out-file -NoClobber -Append "$logFilePath$(Get-Date -UFormat "%Y%m%d")-$logName.log"
}

logFunction -message "Collecting storage accounts from all available subscriptions..." -logname "Alert-AnonymousStorage"

# Loop through all subscriptions
$UnapprovedContainers = @()
Foreach ($Sub in $allActiveSubscriptions)
{
    
    Select-AzSubscription -Subscriptionid $Sub.id | out-null

    # Loop through storage accounts, grab the key and set context for storage account, get its containers
    foreach($SA in (Get-AzStorageAccount))
    {
        write-output "checking storage account => $($SA.StorageAccountName)"
		
		$Key = Get-AzStorageAccountKey -StorageAccountName $SA.StorageAccountName -ResourceGroupName $SA.ResourceGroupName
        $Context = New-AzStorageContext -StorageAccountName $SA.StorageAccountName -StorageAccountKey $key[0].Value
        $Containers = Get-AzStorageContainer -Context $context
		
        foreach ($Container in $Containers)
        {
            # If a container is set to anything other than private, get details
			if ($Container.PublicAccess -ne "Off" -and $SA.AllowBlobPublicAccess -ne $False -and $SA.StorageAccountName -notin $Exceptions)
            {               
                $ContainerProps = [ordered]@{
                    SAName          = $SA.StorageAccountName
                    SAPublicAccess  = $SA.AllowBlobPublicAccess
                    RGName          = $SA.ResourceGroupName
                    Location        = $SA.Location
                    ContainerName   = $Container.Name
                    LastModified    = $Container.LastModified
                    PublicAccess    = $Container.PublicAccess
                    Subscription    = $Sub.Name
                    Owner           = $SA.Tags['owner']
                    Environment     = $SA.Tags['environment']
                    Application     = $SA.Tags['application']
                    CostCenter      = $SA.Tags['costCenter']
                    
                }

                logFunction -message "Public container detected! => $($SA.StorageAccountName)" -logname "Alert-AnonymousStorage"

                $ContainerObj = New-Object -TypeName PSObject -Property $ContainerProps
                
                # Add to unapproved containers object
                $UnapprovedContainers += $ContainerObj
                
                # Send alert
                $SendMailCheck = $True
            }        
        }
    }
}

logFunction -message "Storage account collection complete." -logname "Alert-AnonymousStorage"

If ($SendMailCheck -eq $True)
{
$Header = @"
<style>
@charset "UTF-8";
table {font-family:Calibri;border-collapse:collapse;background-color: #f1f1f1}
td
{font-size:1em;border:1px solid #2191ca;padding:5px 5px 5px 5px;}
th
{font-size:1em;border:1px solid #2191ca;text-align:center;padding-top:px;padding-bottom:4px;padding-right:4px;padding-left:4px;background-color:#2191ca ;color:#ffffff;}
</style> 
<h2 style="Calibri";> Alert: Anonymous Storage </h2>
<h4 style="Calibri";> Anonymous storage accounts have been detected. If this is expected, add the storage account name to the list of exclusions. </h4>
"@

    $emailBody += $header
    $emailBody += $UnapprovedContainers | ConvertTo-HTML
    
    # Send via SendGrid
    $params = @{
        "ToEmailAddress"="xxx";
        "FromEmailAddress"="xxx";
        "Subject"="Alert: Anonymous Storage - " + (Get-Date -DisplayHint Date);
        "Body"= $emailBody;
    }

    ## Set Context of Runbook and call Set-SendGridMessage runbook and pass params for email
    $AzureContext = Set-AzContext -SubscriptionId "xxx"
    Start-AzAutomationRunbook  –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $aaResourceGroup  –Parameters $params

}

# Capture endTime and log duration
$ScriptEndTime = (Get-Date)
logFunction -message $('Script run complete. Total Execution Time: {0:mm} min {0:ss} sec' -f ($ScriptEndTime-$ScriptStartTime)) -logname "Alert-AnonymousStorage"



