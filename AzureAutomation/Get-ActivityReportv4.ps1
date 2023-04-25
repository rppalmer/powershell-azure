<# 
.SYNOPSIS 
    Report on various Azure Resources
.DESCRIPTION 
    The Focus is around awareness of new resources deployed into Azure. Data is pulled
    from the AzureActivity Table in Log Analytics.
.NOTES   
    Version:        4.0
    Author:         Ryan Palmer
    Creation Date:  1/15/2021
    Purpose/Change: Updated to use log analytics (faster)
    File Name  : Get-ActivityReportv4.ps1 

    Update: 3,0 - 1/15/2021 - Reworked script to use function to pull all activity from azlog
    Update: 3.1 - 2/2/2021 - Added Resource Provider function/check and subscription stats
    Update: 4.0 - 6/7/2022 - Rewrite using log analytics
    
#>

$automationAccount      = "xxx"                        # Azure Automation Account Name
$resourceGroup          = "xxx"                  # Azure Automation Account Resource Group Name
$days                   = 1                                         # Lookback (days)
$WorkspaceId            = "xxxx"    # Log Analytics Workspace Id for query
$TenantId               = "xxx"

# Suppress Breaking Change Warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

######################################## 
## Connection Data (Managed identity) ##
########################################

# Connect with Managed Identity
Connect-AzAccount -Identity

# Get Graph Token
$GraphURL = "https://graph.microsoft.com/" 
$Response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing `
-Uri "$($env:IDENTITY_ENDPOINT)?resource=$GraphURL" -Method 'GET' -Headers `
@{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
$graphToken = $Response.access_token 

# Store Context
$context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext

# Get AAD Token
$aadToken = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, `
$context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never,`
$null, "https://graph.windows.net").AccessToken

# Connect to Azure AD
Connect-AzureAD -AadAccessToken $aadToken -AccountId $context.Account.Id -TenantId $context.tenant.id -MsAccessToken $graphToken

###########################
## END / Connection Data ##
###########################

$allSubscriptions = Get-AzSubscription | Select-Object Name, Id, state
$allActiveSubscriptions = $allSubscriptions | Where-Object {$_.State -eq "Enabled"}
$allServicePrincipals = Get-AzureADServicePrincipal -all $true | Select-Object ObjectId, Displayname, AppId
$allUsers = Get-AzureADUser -all $true | Select-Object ExtensionProprety, DisplayName, UserPrincipalName, UserType, AccountEnabled

function CreateCSVAttachment 
{
    param
    (
        [parameter(Mandatory=$true)]
        [array] $data,
        [parameter(Mandatory=$true)]
        [string] $filename
    )

    $dataCSV = $data | ConvertTo-CSV -NoTypeInformation | % {($_).replace('"','') + [System.Environment]::NewLine}
    $encodedData = [System.Text.Encoding]::ASCII.GetBytes($dataCSV)
    $encodedB64 = [System.Convert]::ToBase64String($encodedData)
    
    $attachProps = @{
        "content" = $encodedB64 
        "disposition" = "attachment"
        "filename" = "$filename"
        "type" = "text/csv"
    }

     return $attachProps
}

# Check if resource provider is registered
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

########################################
## Recently Created and Deleted Users ##
########################################

# Log Analytics Query - User Activity
$UserActivityQuery = @"
let days = $days`d;
AuditLogs
| where TimeGenerated >= ago(days)
| where OperationName contains "Add User" or OperationName contains "Delete User"
| extend UPN = TargetResources[0].userPrincipalName
| extend UserType = TargetResources[0].type
| extend MProp0 = TargetResources[0].modifiedProperties[0]
| extend MProp1 = TargetResources[0].modifiedProperties[1]
| extend MProp2 = TargetResources[0].modifiedProperties[2]
| extend MProp3 = TargetResources[0].modifiedProperties[3]
| extend MProp4 = TargetResources[0].modifiedProperties[4]
| extend MProp5 = TargetResources[0].modifiedProperties[5]
| extend MProp6 = TargetResources[0].modifiedProperties[6]
| extend MProp7 = TargetResources[0].modifiedProperties[7]
| extend MProp8 = TargetResources[0].modifiedProperties[8]
| extend MProp9 = TargetResources[0].modifiedProperties[9]
| extend MProp10 = TargetResources[0].modifiedProperties[10]
| extend MProp11 = TargetResources[0].modifiedProperties[11]
| extend MProp12 = TargetResources[0].modifiedProperties[12]
| extend MProp13 = TargetResources[0].modifiedProperties[13]
| extend MProp14 = TargetResources[0].modifiedProperties[14]
| extend MProp15 = TargetResources[0].modifiedProperties[15]
| extend MProp16 = TargetResources[0].modifiedProperties[16]
| extend MProp17 = TargetResources[0].modifiedProperties[17]
| extend MProp18 = TargetResources[0].modifiedProperties[18]
| extend MProp19 = TargetResources[0].modifiedProperties[19]
| extend MProp20 = TargetResources[0].modifiedProperties[20]
| project ActivityDateTime,UPN,UserType,TargetResources,MProp0,MProp1,MProp2,MProp3,MProp4,MProp5,MProp6,MProp7,MProp8,MProp9,MProp10,MProp11,MProp12,MProp13,MProp14,MProp15,MProp16,MProp17,MProp18,MProp19,MProp20,OperationName,Category,CorrelationId,InitiatedBy,Identity
"@

# Run Log Analytics Query
$UsersArr = @()
$NewUsers =  (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $UserActivityQuery).Results 
foreach ($NewUser in $NewUsers)
{
    # Modified Properties are not guaranteed to be in the same order each time. Parse properties
    foreach ($Property in ($NewUser.PSObject.Properties | Where-Object {$_.name -match "MProp"}))
    {
        if ($Property.Value)
        {
            if (($Property.Value | ConvertFrom-Json).displayName -eq "DisplayName"){$DisplayName = (($Property.Value | ConvertFrom-Json).NewValue).trim('[',']','"') }
            if (($Property.Value | ConvertFrom-Json).displayName -eq "UserType"){$UserType = (($Property.Value | ConvertFrom-Json).NewValue).trim('[',']','"')}
            if (($Property.Value | ConvertFrom-Json).displayName -eq "AccountEnabled"){$AccountEnabled = (($Property.Value | ConvertFrom-Json).NewValue).trim('[',']','"')}
            if (($Property.Value | ConvertFrom-Json).displayName -eq "JobTitle"){$JobTitle = (($Property.Value | ConvertFrom-Json).NewValue).trim('[',']','"')}
        }
    }

    # Extract correct caller information
    if (($newUser.initiatedby | convertfrom-json).app)
    {
        $Caller = ($newUser.initiatedby | convertfrom-json).app.serviceprincipalid
        
    }elseif (($newUser.initiatedby | convertfrom-json).User)
    {
        $Caller = ($newUser.initiatedby | convertfrom-json).user.userprincipalname
    }elseif ($NewUser.Identity)
    {
        $Caller = $NewUser.Identity
    }

    if ($caller -match "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    {
        $Caller = ($allServicePrincipals | Where-Object {$_.ObjectId -eq $Caller}).DisplayName
    }

    # Delete operation stores values differently
    if ($NewUser.OperationName -eq "Delete User")
    {
        $Displayname = ''
        $JobTitle    = ''
        $AccountEnabled = 'false'
        $UserType = $NewUser.UserType
    }

    $UserProps = [ordered]@{
        Caller           = $Caller
        OperationName    = $NewUser.OperationName
        DisplayName      = $DisplayName
        Type             = $UserType
        UPN              = $NewUser.UPN
        JobTitle         = $JobTitle
        Enabled          = $AccountEnabled  
        ActivityTime     = $NewUser.ActivityDateTime

    }
    $UserObj = New-Object -TypeName PSObject -Property $UserProps
    $UsersArr += $UserObj
    Clear-Variable UserObj
}

####################################################
## Recently Created and Deleted App Registrations ##
####################################################

$SPActivityQuery = @"
let days = $days`d;
AuditLogs
| where TimeGenerated >= ago(days)
| where OperationName contains "Add Application" or OperationName contains "Delete Application"
| extend DisplayName = TargetResources[0].displayName
| extend UserType = TargetResources[0].type
"@

# Run Log Analytics Query
$SPsArr = @()
$SPActivity =  (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $SPActivityQuery).Results 
foreach ($SP in $SPActivity)
{

    # Extract correct caller objectid or upn
    if (($SP.initiatedby | convertfrom-json).app){$Caller = ($SP.initiatedby | convertfrom-json).app.serviceprincipalid}
    elseif (($SP.initiatedby | convertfrom-json).User){$Caller = ($SP.initiatedby | convertfrom-json).user.userprincipalname}
    elseif ($SP.Identity){$Caller = $SP.Identity}

    if ($caller -match "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    {
        $Caller = ($allServicePrincipals | Where-Object {$_.ObjectId -eq $Caller}).DisplayName
    }

    $SPProps = [ordered]@{
        Caller           = $Caller
        OperationName    = $SP.OperationName
        DisplayName      = $SP.DisplayName
        Type             = $SP.UserType
        ActivityTime     = $SP.ActivityDateTime
    }
    $SPObj = New-Object -TypeName PSObject -Property $SPProps
    $SPsArr += $SPObj
    Clear-Variable SPObj
}

##########################
## Recently Created VMs ##
##########################

$VMActivityQuery = @"
let days = $days`d;
AzureActivity
| where TimeGenerated >= ago(days)
| where OperationNameValue =~ "microsoft.compute/virtualMachines/write"
| where ResourceGroup !contains "citrix-xd"
| where ResourceGroup !contains "databricks-rg"
| where ActivitySubstatus == "Created (HTTP Status Code: 201)"
"@

$VMActivityArr = @()
$VMActivities =  (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $VMActivityQuery).Results 
$VMActivities = $VMActivities | Sort-Object -Property Resource,OperationNameValue -Unique
foreach ($VMActivity in $VMActivities)
{
    $SubscriptionName = ($allSubscriptions | Where-Object {$_.id -eq $VMActivity.SubscriptionId}).name
    
    if ($VMActivity.caller -match "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    {
        $Caller = ($allServicePrincipals | Where-Object {$_.ObjectId -eq $VMActivity.Caller}).DisplayName
    }else{
        $Caller = $VMActivity.Caller
    }

    $VMActivityProps = [ordered]@{
        Caller              = $Caller
        Operation           = $VMActivity.OperationNameValue
        Name                = $VMActivity.Resource
        ResourceGroup       = $VMActivity.ResourceGroup
        Type                = ($VMActivity.ResourceId -split "/")[-2]
        ResourceProvider    = $VMActivity.ResourceProviderValue
        Subscription        = $SubscriptionName
        DateCreated         = $VMActivity.TimeGenerated
    }
    $VMObj = New-Object -TypeName PSObject -Property $VMActivityProps
    $VMActivityArr += $VMObj
    Clear-Variable VMObj
    Clear-Variable SubscriptionName
    Clear-Variable Caller
}

##################################################
## Recently Created and Deleted Azure Resources ##
##################################################

$AzureActivityQuery = @"
let days = $days`d;
AzureActivity
| where TimeGenerated >= ago(days)
| extend _Resource = parse_json(Properties).resource
| where ResourceGroup !contains "Citrix"
| where ResourceGroup !contains "Databricks"
| where OperationNameValue contains "Write" or OperationNameValue contains "Delete"
| where OperationNameValue !contains "microsoft.insights/components" and OperationNameValue !contains "microsoft.alertsmanagement/smartdetectoralertrules" and OperationNameValue !contains "Microsoft.SecurityInsights/Incidents/write" and OperationNameValue !contains "Microsoft.Compute/restorePointCollections" and OperationNameValue !contains "Microsoft.Compute/snapshots" and OperationNameValue !contains "Microsoft.Compute/virtualMachineScaleSets" and OperationNameValue !contains "Microsoft.Authorization/locks/write" and OperationNameValue !contains "microsoft.operationalinsights/workspaces"
| where ActivityStatusValue contains "Success" or ActivityStatusValue contains "Succeeded" or ActivityStatusValue contains "Failed" or ActivityStatusValue contains "failure"
| where Resource != "VMSnapshot"
| project TimeGenerated,Caller,CallerIpAddress,OperationNameValue,_Resource,ResourceGroup,SubscriptionId,ResourceProviderValue,_ResourceId,ActivityStatusValue
"@

# Run Log Analytics Query and Dedupe
$ActivityArr = @()
$AzureActivity =  (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $AzureActivityQuery).Results 
$AzureActivity = $AzureActivity | Sort-Object -Property _Resource,OperationNameValue -Unique
foreach ($Activity in $AzureActivity)
{
    $SubscriptionName = ($allSubscriptions | Where-Object {$_.id -eq $Activity.SubscriptionId}).name
    
    if ($Activity.caller -match "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
    {
        $Caller = ($allServicePrincipals | Where-Object {$_.ObjectId -eq $Activity.Caller}).DisplayName
    }else{
        $Caller = $Activity.Caller
    }

    $ActivityProps = [ordered]@{
        Caller              = $Caller
        Operation           = $Activity.OperationNameValue
        Status              = $Activity.ActivityStatusValue
        Name                = $Activity._Resource
        ResourceGroup       = $Activity.ResourceGroup
        Type                = ($activity._ResourceId -split "/")[-2]
        Subscription        = $SubscriptionName
        DateCreated         = $Activity.TimeGenerated
    }
    $ActivityObj = New-Object -TypeName PSObject -Property $ActivityProps
    $ActivityArr += $ActivityObj
    Clear-Variable ActivityObj
    Clear-Variable SubscriptionName
    Clear-Variable Caller
}

######################
## High Level Stats ##
######################

$StatsArr = @()     
foreach ($subscription in $allActiveSubscriptions)
{
    
    Select-AzSubscription -SubscriptionId $Subscription.Id -TenantId $TenantId | Out-Null

    try
    {
        $Providers = Get-AzResourceProvider -ListAvailable
    }catch{
        "subscription in a state that prevents provider listing"
    }

    # If provider list is empty, no reason to check
    if ($null -ne $Providers)
    {

        $ProviderCheck = CheckProvider -provider "Microsoft.Compute" -ProviderList $Providers
        if ($providerCheck -eq $true){$VMCount = (Get-AzVM | Select-Object Name).count}
        if ($null -eq $VMCount){$VMCount = 0}
        $GTVMCount += $VMCount

        $ProviderCheck = CheckProvider -provider "Microsoft.Storage" -ProviderList $Providers
        if ($providerCheck -eq $true){$SAsTotal = (Get-AzStorageAccount | Select-Object Name).count}
        if ($null -eq $SAsTotal){$SAsTotal = 0}
        $GTSAsTotal += $SAsTotal

        $ProviderCheck = CheckProvider -provider "Microsoft.KeyVault" -ProviderList $Providers
        if ($providerCheck -eq $true){$KVTotal = (Get-AzKeyVault | Select-Object Name).count}else{$KVTotal = 0}
        if ($null -eq $KVTotal){$KVTotal = 0}
        $GTKVTotal += $KVTotal
        
        $ProviderCheck = CheckProvider -provider "Microsoft.Network" -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            $VNetTotal = (Get-AzVirtualNetwork | Select-Object Name).count 
            $GTVNetTotal += $VNetTotal
            $PIPs = Get-AzPublicIpAddress | Select-Object Name, IPAddress
            $PIPTotal = ($PIPs | Select-Object Name, IpAddress).count
            $GTPIPTotal += $PIPTotal
            $PIPTotalActive = ($PIPs | Where-Object {$_.IpAddress -notmatch "Not Assigned"}).count 
            $GTPIPTotalActive += $PIPTotalActive
            $LBCount = (Get-AzLoadBalancer | Select-Object Name).count
            $GTLBCount += $LBCount
        }
        if ($null -eq $VNetTotal){$VNetTotal = 0}
        if ($null -eq $PIPs){$PIPs = 0}
        if ($null -eq $PIPTotal){$PIPTotal = 0}
        if ($null -eq $PIPTotalActive){$PIPTotalActive= 0}
        if ($null -eq $LBCount){$LBCount = 0}
        
        $ProviderCheck = CheckProvider -provider "Microsoft.Web" -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            $ASPCount = (Get-AzAppServicePlan | Select-Object Name).count 
            $GTASPCount += $ASPCount
            $WebAppCount = (Get-AzWebApp | Select-Object Name).count
            $GTWebAppCount += $WebAppCount
        }
        if ($null -eq $WebAppCount){$WebAppCount = 0}
        if ($null -eq $ASPCount){$ASPCount = 0}
        
        $ProviderCheck = CheckProvider -provider "Microsoft.Sql" -ProviderList $Providers
        if ($providerCheck -eq $true){
            $SQLServers = Get-AzSQLServer
            $SQLServerCount = ($SQLServers | Select-Object Name).count
            $GTSQLServerCount += $SQLServerCount
            $SQLDatabaseCount = ($SQLServers | Get-AzSqlDatabase | Select-Object databasename | where-object {$_.databasename -ne "master"}).count
            $GTSQLDatabaseCount += $SQLDatabaseCount
        }
        if ($null -eq $SQLServers){$SQLServers = 0}
        if ($null -eq $SQLServerCount){$SQLServerCount = 0}
        if ($null -eq $SQLDatabaseCount){$SQLDatabaseCount = 0}
        
        # DNS Zones only exist in Legacy Sub
        if ($subscription.id -eq "67e6c130-213c-4abf-bc98-db9a0825428e"){$ZoneTotal = (Get-AzDnsZone).count}else{$ZoneTotal = 0}  
        $GTZoneTotal += $ZoneTotal   

        $SubProps = [ordered]@{
            "SubscriptionName" = $subscription.Name
            "VMs"       = $VMCount
            "VNets"     = $VNetTotal
            "PIP (T)"   = $PIPTotal
            "PIP (A)"   = $PIPTotalActive
            "LBs"       = $LBCount
            "ASPs"      = $ASPCount
            "WebApps"   = $WebAppCount
            "SAs"       = $SAsTotal
            "SQL (S)"   = $SQLServerCount
            "SQL (D)"   = $SQLDatabaseCount
            "KVs"       = $KVTotal
            "DNSZones"  = $ZoneTotal
        }
        $SubObj = New-Object -TypeName PSObject -Property $SubProps
        $StatsArr += $SubObj

        # Clear variables if not empty, this is a catch all to prevent carry over counts
        if ($VMCount){Clear-Variable VMCount}
        if ($VNetTotal){Clear-Variable VNetTotal}
        if ($PIPs){Clear-Variable PIPTotal}
        if ($PIPTotal){Clear-Variable PIPTotal}
        if ($PIPTotalActive){Clear-Variable PIPTotalActive}
        if ($LBCount){Clear-Variable LBCount}
        if ($ASPCount){Clear-Variable ASPCount}
        if ($WebAppCount){Clear-Variable WebAppCount}
        if ($SAsTotal){Clear-Variable SAsTotal}
        if ($SQLServers){Clear-Variable SQLServers}
        if ($SQLServerCount){Clear-Variable SQLServerCount}
        if ($SQLDatabaseCount){Clear-Variable SQLDatabaseCount}
        if ($KVTotal){Clear-Variable KVTotal}
        if ($ZoneTotal){Clear-Variable ZoneTotal}
    }
}

# Add Grand Totals
$GTProps = [ordered]@{
    "SubscriptionName" = "Grand Total"
    "VMs"       = $GTVMCount
    "VNets"     = $GTVNetTotal
    "PIP (T)"   = $GTPIPTotal
    "PIP (A)"   = $GTPIPTotalActive
    "LBs"       = $GTLBCount
    "ASPs"      = $GTASPCount
    "WebApps"   = $GTWebAppCount
    "SAs"       = $GTSAsTotal
    "SQL (S)"   = $GTSQLServerCount
    "SQL (D)"   = $GTSQLDatabaseCount
    "KVs"       = $GTKVTotal
    "DNSZones"  = $GTZoneTotal
}
$GTObj = New-Object -TypeName PSObject -Property $GTProps
$StatsArr += $GTObj


##################
## Email Report ##
##################

# High-Level Tenant Stats
$allUserCount = ($allUsers | Select-Object UserType, AccountEnabled).count
$allUserGuestCount = ($allUsers | Where-Object {$_.UserType -eq "Guest"}).count
$allUserEnabled = ($allUsers | Where-Object {$_.AccountEnabled -eq "True" -and $_.UserType -ne "Guest"}).count
$allSubscriptionsCount = ($allSubscriptions).count
$allServicePrincipalsCount = ($allServicePrincipals).count
$AttachArr = @() 

$Header = @"
<style>
@charset "UTF-8";
table {font-family:Calibri;border-collapse:collapse;background-color: #f1f1f1}
td
{font-size:1em;border:1px solid #2191ca;padding:5px 5px 5px 5px;}
th
{font-size:1em;border:1px solid #2191ca;text-align:center;padding-top:px;padding-bottom:4px;padding-right:4px;padding-left:4px;background-color:#2191ca ;color:#ffffff;}
</style>
<h2 style="Calibri";> Azure Activity Report </h2>
<li style="Calibri";> Lookback (days): $days </li>
<li style="Calibri";> Users: $allUserCount </li>
<li style="Calibri";> Guests: $allUserGuestCount </li>
<li style="Calibri";> Enabled Users (Non-Guest): $allUserEnabled </li>
<li style="Calibri";> Subscriptions: $allSubscriptionsCount </li>
<li style="Calibri";> Service Principals: $allServicePrincipalsCount </li>
"@
$emailBody += $header
$emailBody += "<h3 style='Calibri;'> Resource Counts </h3>"
$emailBody += $StatsArr | ConvertTo-HTML

$emailBody += "<h3 style='Calibri;'> Recently Created and Deleted Users </h3>" # Add UsersArr to email body and create attachment
If (!$UsersArr)
{
    $UsersArr="[no data]";$emailBody += $UsersArr
}Else{
    $emailBody += $UsersArr | ConvertTo-HTML
    $attachArr += CreateCSVAttachment -data $UsersArr -filename "Users.csv"
    Clear-Variable UsersArr
}

$emailBody += "<h3 style='Calibri;'> Recently Created and Deleted App Registrations </h3>" # Add Recently Created and Deleted Sps to email body and create attachment
If (!$SPsArr){
    $SPsArr="[no data]"
    $emailBody += $SPsArr
}Else{
    $emailBody += $SPsArr | ConvertTo-HTML
    $attachArr += CreateCSVAttachment -data $SPsArr -filename "ServicePrincipals.csv"
    Clear-Variable SPsArr}

$emailBody += "<h3 style='Calibri;'> Recently Created VMs </h3>" # Add Recently created VMs to email body and create attachment
If (!$VMActivityArr)
{
    $VMActivityArr="[no data]"
    $emailBody += $VMActivityArr
}Else{
    $emailBody += $VMActivityArr | ConvertTo-HTML
    $attachArr += CreateCSVAttachment -data $VMActivityArr -filename "CreatedVMs.csv"
    Clear-Variable VMActivityArr}

$emailBody += "<h3 style='Calibri;'> Recently Created and Deleted Azure Resources </h3>" # Add Recently created and deleted Azure Resources to email body and create attachment
If (!$ActivityArr)
{
    $ActivityArr="[no data]"
    $emailBody += $ActivityArr
}Else{
    $emailBody += $ActivityArr | ConvertTo-HTML
    $attachArr += CreateCSVAttachment -data $ActivityArr -filename "Activity.csv"
    Clear-Variable ActivityArr}

# Send via SendGrid
$params = @{
    ToEmailAddress = "xxx";
	AdditionalRecipient1 = "xxx";
    FromEmailAddress = "xxx";
    Subject = "Azure Activity Report - " + (Get-Date -DisplayHint Date);
    Body = $emailBody;
    Attachments = $AttachArr
}

# Set Context of Runbook and call Set-SendGridMessage runbook and pass params for email
$AzureContext = Set-AzContext -SubscriptionId "xxx"
Start-AzAutomationRunbook  –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $resourceGroup –Parameters $params