<# 
.SYNOPSIS 
    Report for users that haven't logged on in 30 days or more.
.DESCRIPTION 
    Report for users that haven't logged on in 30 days or more. 
.NOTES   
    Version:        2.0 
    Author:         Ryan Palmer
    Creation Date:  10/7/2021
    Purpose/Change: Initial Script Creation
    1/14/2022 - Removed mailbox lastlagon lookup because it was unneeded and slowed script down. Utilizing log analytics vs Azure AD sign ins to improve speed.
    4/27/2022 - Updated CSV convert function to not put leading spaces in line breaks. Updated filter to remove accounts that are newly created > 30 days ago but haven't logged in yet.
    
#>

Import-Module AzureADPreview

$automationAccount  = "xxx" 
$resourceGroup      = "xxx"
$DateThreshold      = (Get-Date).AddDays(-30)
$AttachArr          = @()
$ExcludedUPNList = [ordered]@{
    "name@domain.com" = "description"
}


###############
### CONNECT ###
###############

## Connect with Managed Identity
Connect-AzAccount -Identity

## Connect to Exchange Online
$resourceURI = "https://outlook.office365.com/"
$tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthURI
$accessToken = $tokenResponse.access_token
$Authorization = "Bearer {0}" -f $accessToken 
$Password = ConvertTo-SecureString -AsPlainText $Authorization -Force
$Ctoken = New-Object System.Management.Automation.PSCredential -ArgumentList "OAuthUser@483fadee-89c9-4311-912d-37212c6f09aa",$Password
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/PowerShell-LiveId?BasicAuthToOAuthConversion=true -Credential $Ctoken -Authentication Basic -AllowRedirection -Verbose

Import-PSSession $Session | Format-List

## connect to Azure AD
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

#################
### / CONNECT ###
#################

# Convert timestamp
function Convert-TimeStamp
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $TimeObject,
        [Parameter(Mandatory=$false, Position=1)]
        [string] $TimeZone = 'Eastern Standard Time'
    )

    $UniversalTime = ([DateTime]$TimeObject).ToUniversalTime()
    [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($UniversalTime, $TimeZone)

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

## NEW QUERY
$Query = @"
let days = 365d;
SigninLogs 
| where TimeGenerated > ago(days)
| mv-expand parse_json("AuthenticationDetails")
| extend authenticationSuccess_ = tostring(parse_json(AuthenticationDetails)[0].succeeded)
| where authenticationSuccess_ == "true"
| summarize arg_max(TimeGenerated,*) by UserPrincipalName
| project UserPrincipalName, TimeGenerated, AppDisplayName, DeviceDetail, ClientAppUsed
"@

$WorkspaceId = 'xxx'
$LogAnalyticsLatestSignInData =  (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $Query).Results 

# Get shared mailboxes (only old cmdlets work for now...)
$MailboxData = Get-Mailbox -ResultSize Unlimited | Select-Object userPrincipalName, recipientTypeDetails

$UserResultsArr = @()
# For each enabled non-guest account that is not in the SailpointTest or Service Accounts OU 
foreach ($User in Get-AzureADUser -all:$true | Where-Object {`
    $_.AccountEnabled -eq $True -and `
    $_.UserType -ne "Guest" -and `
    $_.UserPrincipalName -notin $ExcludedUPNList.Keys -and `
    $_.ExtensionProperty.onPremisesDistinguishedName -notmatch "Service Accounts"}) 
{    

    # Get last logon date from Azure AD
    $UserAADSignInInfo = $LogAnalyticsLatestSignInData | Where-Object {$_.UserPrincipalName -eq $User.UserPrincipalName}

    # Convert Azure Active Directory Sign-in Timestamp to Eastern, skip if no time stamp
    Try{$AADUserLastLogonTimestamp = Convert-TimeStamp -TimeObject $UserAADSignInInfo.TimeGenerated}Catch{$AADUserLastLogonTimestamp = "not available"}

    # Convert Created Timestamp to Eastern, skip if no time stamp
    Try{$AADUserCreatedTimestamp = Convert-TimeStamp -TimeObject $User.ExtensionProperty.createdDateTime}Catch{$AADUserCreatedTimestamp = "not available"}
        
    # if AAD Sign in older than DateThreshold or NULL
    if (($AADUserLastLogonTimestamp -lt $DateThreshold -or $AADUserLastLogonTimestamp -eq "not available") -and $AADUserCreatedTimestamp -lt $DateThreshold)
    {
        
        # Replace , with / in string to avoid issue with export-csv. If blank DN, add string to indicate
        if ($null -ne $User.ExtensionProperty.onPremisesDistinguishedName){$DN = $User.ExtensionProperty.onPremisesDistinguishedName}else{$DN = "not available"}

        # Check if device detail,clientapp,appdisplayname populated, if not set the variable to not available to avoid errors.
        if ($null -ne $UserAADSignInInfo.DeviceDetail){$AADLogonDeviceUsed = ($UserAADSignInInfo.DeviceDetail | ConvertFrom-Json).displayName}else{$AADLogonDeviceUsed = "not available"}
        if ($null -ne $UserAADSignInInfo.ClientAppUsed){$AADLogonAppUsed = $UserAADSignInInfo.ClientAppUsed}else{$AADLogonDeviceUsed  = "not available"}
        if ($null -ne $UserAADSignInInfo.AppDisplayName){$AADLogonAppDisplayName = $UserAADSignInInfo.AppDisplayName}else{$AADLogonDeviceUsed  = "not available"}

        # Detect mailbox type (if available)
        $ResourceType = ($MailboxData | Where-Object {$_.UserPrincipalName -eq $User.UserPrincipalName}).recipientTypeDetails

        # Mark as not available if resource type not found
        if ($null -eq $ResourceType){$ResourceType = "not available"}

        $DisplayName = ($User.DisplayName).trim()

        # Create custom object
        $UserProps = [ordered]@{
            Displayname                 = $DisplayName
            AccountEnabled              = $User.AccountEnabled
            physicalDeliveryOfficeName  = $User.physicalDeliveryOfficeName
            CreatedTimeStamp            = $AADUserCreatedTimestamp
            AADUserLastLogonTimestamp   = $AADUserLastLogonTimestamp
            O365ResourceType            = $ResourceType
            DistinguishedName           = $DN
            samAccountName              = ($User.userPrincipalName -split "@")[0]
            userPrincipalName           = $User.userPrincipalName
            Department                  = $User.Department
            Manager                     = (Get-AzureADUserManager -ObjectId $User.UserPrincipalName).DisplayName
            JobTitle                    = $User.JobTitle
            EmployeeId                  = $User.ExtensionProperty.employeeId
            Reviewer                    = ""
            Comments                    = ""
            AADLogonAppUsed             = $AADLogonAppUsed
            AADLogonAppDisplayName      = $AADLogonAppDisplayName 
            AADLogonDeviceUsed          = $AADLogonDeviceUsed 

        }

        $UserResultsObj = New-Object -TypeName PSObject -Property $UserProps
        $UserResultsArr += $UserResultsObj
        
        # Clean up variables to prevent accidental reuse
        if($AADUserLastLogonTimestamp){Clear-Variable AADUserLastLogonTimestamp}
        if($MostRecentSignIn){Clear-Variable MostRecentSignIn}
        if($UniversalTime){Clear-Variable UniversalTime}
        if($MailboxLogonTimestamp){Clear-Variable MailboxLogonTimestamp}
        if($AADLogonAppUsed){Clear-Variable AADLogonAppUsed}
        if($AADLogonAppDisplayName){Clear-Variable AADLogonAppDisplayName}
        if($AADLogonDeviceUsed){Clear-Variable AADLogonDeviceUsed}
        if($DN){Clear-Variable DN}
    }
}

Remove-PSSession $Session

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
<h2 style="Calibri";> Accounts that haven't logged in since $DateThreshold or earlier </h2>
<h3 style="Calibri";> Note: if any false positives are found please provide userPrincipalName to Security Team so it can be added to exclusions. </h3>

"@

$EmailBody += $header

# If there are no results add 'no data' to array to indicate this
If (!$UserResultsArr)
{
    $UserResultsArr = "[no data]"
    $EmailBody += $UserResultsArr
# Otherwise add the content to the body of the email and also create an attachment
}Else{

    $EmailBody += $UserResultsArr | ConvertTo-HTML
    $AttachArr += Get-CSVAttachment -data $UserResultsArr -filename "Signins_30days.csv"
}

# Build Excluded VPNs Object
$ExcludedUPNArr = @()
Foreach ($ExcludedUPN in $ExcludedUPNList.GetEnumerator())
{
    $ExcludedUPNProps = [Ordered]@{
        UPN = $ExcludedUPN.Key
        Description = $ExcludedUPN.Value
    }

    $ExcludedUPNObj = New-Object -TypeName PSObject -Property $ExcludedUPNProps
    $ExcludedUPNArr += $ExcludedUPNObj
}

# Create attachment for excluded UPNs/Descriptions
$AttachArr += Get-CSVAttachment -data $ExcludedUPNArr -filename "Excluded_UPNs.csv"

# Send via SendGrid
$params = @{
    ToEmailAddress = "xxx";
    AdditionalRecipient1 = "xxx";
    AdditionalRecipient2 = "xxx";
    FromEmailAddress = "xxx";
    Subject = "Account Sign-in Report - " + (Get-Date -DisplayHint Date);
    Body = $EmailBody;
    Attachments = $AttachArr
}

## Call Set-SendGridMessage runbook and pass params for email
Start-AzAutomationRunbook  –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $resourceGroup –Parameters $params