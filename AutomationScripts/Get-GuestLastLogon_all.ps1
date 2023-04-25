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
    
#>

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

Import-Module AzureADPreview

$ExcludedUPNs        = @("")
$Outfile             = "c:\tmp\guestaccountdump.csv"

# Connect
Connect-AzureAD
Connect-AzAccount

## Log Analytics Query
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


# For each enabled non-guest account that is not in the exclusion list
foreach ($User in Get-AzureADUser -all:$true | Where-Object {`
    $_.AccountEnabled -eq $True -and `
    $_.UserType -eq "Guest" -and `
    $_.UserPrincipalName -notin $ExcludedUPNs }) 
{    

    foreach ($Email in $User.OtherMails)
    {

        # Get last logon date from Azure AD
        $UserAADSignInInfo = $LogAnalyticsLatestSignInData | Where-Object {$_.UserPrincipalName -eq $Email}

        # Convert Azure Active Directory Sign-in Timestamp to Eastern, skip if no time stamp
        Try{
            $AADUserLastLogonTimestamp = Convert-TimeStamp -TimeObject $UserAADSignInInfo.TimeGenerated
        } Catch {
            #Write-Output "[*] No timestamp found for $($User.userPrincipalName)"
            $AADUserLastLogonTimestamp = "not available"
        }          
            
        # Create custom object
        $UserProps = [ordered]@{
            Displayname                 = $User.DisplayName
            GuestAccountUPN             = $User.userPrincipalName
            Email                       = $Email
            AccountEnabled              = $User.AccountEnabled
            UserType                    = $User.UserType
            PhysicalDeliveryOfficeName  = $User.physicalDeliveryOfficeName
            CreatedTimeStamp            = $User.ExtensionProperty.createdDateTime
            AADUserLastLogonTimestamp   = $AADUserLastLogonTimestamp
            Department                  = $User.Department
            JobTitle                    = $User.JobTitle
        }

        $UserResultsObj = New-Object -TypeName PSObject -Property $UserProps
        $UserResultsObj | export-csv -Append -NoTypeInformation $Outfile
        
        # Clean up variables to prevent accidental reuse
        if($AADUserLastLogonTimestamp){Clear-Variable AADUserLastLogonTimestamp}
        if($UniversalTime){Clear-Variable UniversalTime}
    }

}   

