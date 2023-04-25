<# 
.SYNOPSIS 
    Retrieve members of dynamic group ane email each manager a list of their directs
.DESCRIPTION 
    Retrieve members of dynamic group ane email each manager a list of their directs
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  3/1/2023

.EXAMPLE

    # Runs against the Active Vendor group and specifies a fallback email for users that don't have managers specified
    Invoke-EmailListOfDirects -GroupDisplayName "Group Name" -FallbackEmail "user@domain.com"

    # Overrides the email address for managers for testing - ALL EMAIL WILL BE SENT TO SPECIFIED ADDRESS
    Invoke-EmailListOfDirects -GroupDisplayName "Group Name" -FallbackEmail "user@domain.com"
    
#>

###############
### CONNECT ###
###############

## Connect with Managed Identity
Connect-AzAccount -Identity
$TenantId = "xxx"

## Connect to Exchange Online
$resourceURI = "https://outlook.office365.com/"
$tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER"="$env:IDENTITY_HEADER"} -Uri $tokenAuthURI
$accessToken = $tokenResponse.access_token
$Authorization = "Bearer {0}" -f $accessToken 
$Password = ConvertTo-SecureString -AsPlainText $Authorization -Force
$Ctoken = New-Object System.Management.Automation.PSCredential -ArgumentList "OAuthUser@$TenantId",$Password
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

$AutomationAccountName  = "xxx" 
$AutomationResourceGroup      = "xxx"

# Function for converting to eastern standard time
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

# Get the latest record from the signin logs table in log analytics (more reliable than pulling from user properties)
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

# Connect to workspace and run the query
$WorkspaceId = 'xxx'
$LogAnalyticsLatestSignInData =  (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $Query).Results 

function Invoke-EmailListOfDirects{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $GroupDisplayName,
        [Parameter(Mandatory=$false, Position=1)]
        [string] $FallbackEmail = 'secops@homepointfinancial.com'
    )

    $GroupMembers = Get-AzADGroup -DisplayName $GroupDisplayName | Get-AzADGroupMember

    $UserArr = @()
    foreach ($Member in $GroupMembers)
    {
        # get additional user information and map to get last logon
        $UserDetails = Get-AzureADUser -ObjectId $Member.Id | Select-Object AccountEnabled, DisplayName, UserPrincipalName, Mail, CompanyName
        $UserManager = Get-AzureADUserManager -ObjectId $UserDetails.UserPrincipalName
        $LastLogonData = $LogAnalyticsLatestSignInData | Where-Object {$_.UserPrincipalName -eq $UserDetails.UserPrincipalName}

        # convert timezone
        Try{$LastLogonTimestamp = Convert-TimeStamp -TimeObject $LastLogonData.TimeGenerated}Catch{$LastLogonData = "not available"}

        # use fallback email
        if (!$UserManager){$UserManagerEmail="$FallbackEmail (Fallback)"}else{$UserManagerEmail=$UserManager.Mail}

        # create custom object with needed columns
        $UserProps = [ordered]@{
            DisplayName     = $UserDetails.DisplayName
            EmailAddress    = $UserDetails.Mail
            CompanyName     = $UserDetails.CompanyName
            AccountEnabled  = $UserDetails.AccountEnabled
            LastLogon       = $LastLogonTimestamp
            ManagerEmail    = $UserManagerEmail
        }
        
        $UserObj = New-Object -TypeName PSObject -Property $UserProps
        $UserArr += $UserObj  
        
        # clean up
        Clear-Variable UserDetails
        Clear-Variable UserManager
    }

    # Group results by manager
    $GroupByManager = $UserArr | Sort-Object -Property ManagerEmail | Group-Object -Property ManagerEmail

# Store email header
$Header = @"
<style>
@charset "UTF-8";
table {font-family:Calibri;border-collapse:collapse;background-color: #f1f1f1}
td
{font-size:1em;border:1px solid #2191ca;padding:5px 5px 5px 5px;}
th
{font-size:1em;border:1px solid #2191ca;text-align:center;padding-top:px;padding-bottom:4px;padding-right:4px;padding-left:4px;background-color:#2191ca ;color:#ffffff;}
</style> 
<p style="Calibri";> As a manager, you must ensure access to Homepoint systems is removed promptly when it's no longer required. </p> 
<p style="Calibri";>Please review the list of non-employees (contractors/vendors) below. If anyone no longer needs access to Homepoint systems, please forward this email to <a href="mailto:HR@hpfc.com">HR@hpfc.com</a> and request that they be offboarded.  Remember to notify <a href="mailto:HR@hpfc.com">HR@hpfc.com</a> to remove access on or before your non-employee's last day. </p>
<p> <b> Note </b> - This list only contains non-employees with an Active Directory account.  If you have non-employees with application only access they will not show on this list, but still must be offboarded promptly. </p>

"@

# get current date
$CurrentDateTime = Convert-TimeStamp -TimeObject (Get-Date -DisplayHint Date) 

# loop through results and email each direct to their manager
    foreach ($Manager in $GroupByManager)
    {
        if (!$Manager.name){
            $ManagerEmail = $FallbackEmail
        }else{
            $ManagerEmail = $Manager.name
        }
        
        $EmailBody += $Header
        $EmailBody += $Manager.Group | ConvertTo-Html
       
        # Send via SendGrid
        $params = @{
            ToEmailAddress = $ManagerEmail;
            FromEmailAddress = "xxx";
            Subject = "Non-Employee Offboarding - " + $CurrentDateTime;
            Body = $EmailBody;
        }   

        ## Call Set-SendGridMessage runbook and pass params for email
        Start-AzAutomationRunbook  –Name 'Set-SendGridMessagev2' -AutomationAccountName $AutomationAccountName -ResourceGroupName $AutomationResourceGroup –Parameters $params

        Clear-Variable EmailBody
    }

     # Send via SendGrid
     $params = @{
        ToEmailAddress = "xxx"
        FromEmailAddress = "xxx";
        Subject = "Alert: Non-Employee Offboarding - " + $CurrentDateTime;
        Body = "Non-Employee Offboarding email kicked off: " + $CurrentDateTime;
    }   

    ## Call Set-SendGridMessage runbook and pass params for email
    Start-AzAutomationRunbook  –Name 'Set-SendGridMessagev2' -AutomationAccountName $AutomationAccountName -ResourceGroupName $AutomationResourceGroup –Parameters $params
}

# Multiple groups can be spcified here
Invoke-EmailListOfDirects -GroupDisplayName "Active Vendor" -FallbackEmail "xxx"
