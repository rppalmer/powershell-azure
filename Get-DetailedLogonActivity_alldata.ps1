# Timestamp and folder path
$timestamp = Get-Date -UFormat "%Y%m%d"
$OutputFolder = "C:\tmp"
$outFile = $OutputFolder+"\"+$timestamp+"_LastLogon_all.csv"
#$DateThreshold = (Get-Date).AddDays(-30)

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
    Return [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($UniversalTime, $TimeZone)
}

#Connect-AzureAD
#Connect-ExchangeOnline

# Get shared mailboxes
$SharedMailboxes = Get-EXOMailbox -filter {recipientTypeDetails -eq "sharedmailbox"} | Select-Object userPrincipalName

# For each enabled non-guest account that is not in the SailpointTest or Service Accounts OU
foreach ($User in Get-AzureADUser -all:$true | Where-Object {`
    $_.AccountEnabled -eq $True -and `
    $_.UserType -ne "Guest" }) 
{    

        # Populate field depending on if account is shared mailbox
        if ($User.userPrincipalName -in $SharedMailboxes.userPrincipalName)
        {
            $SharedMailbox = $True
        } else {
            $SharedMailbox = $False
        }

        # Get last login date from EXO Mailbox
        $MailboxLogonTimeStamp = (Get-MailboxStatistics -Identity $User.userPrincipalName).lastlogontime

        # Get last logon date from Azure AD
        $MostRecentAADSignIn = Get-AzureADAuditSignInLogs -top 1 -filter "userId eq '$($User.ObjectId)'"
            
        # Convert Azure Active Directory Sign-in Timestamp to Eastern, skip if no time stamp
        if ($null -ne $MostRecentAADSignIn){$AADLastLogon = Convert-TimeStamp -TimeObject $MostRecentAADSignIn.CreatedDateTime}else{$AADLastLogon = "not available"}

        # Convert Mailbox Login Timestamp to Eastern, skip if no time stamp
        if ($null -ne $MailboxLogonTimeStamp){$MbxLastLogon = Convert-TimeStamp -TimeObject $MailboxLogonTimeStamp}else{$MbxLastLogon = "not available"}
        
        # This needed?  Looks prettier in report to have not available vs blank but blanks are unavoidable
        if ($null -ne $User.ExtensionProperty.onPremisesDistinguishedName){$DN = $User.ExtensionProperty.onPremisesDistinguishedName}else{$DN = "not available"}

        # Create custom object
        $UserProps = [ordered]@{
            Displayname                 = $User.DisplayName
            AccountEnabled              = $User.AccountEnabled
            physicalDeliveryOfficeName  = $User.physicalDeliveryOfficeName
            CreatedTimeStamp            = $User.ExtensionProperty.createdDateTime
            AADLastLogon                = $AADLastLogon
            MailboxLogonTimestamp       = $MbxLastLogon 
            DistinguishedName           = $DN
            samAccountName              = ($User.userPrincipalName -split "@")[0]
            userPrincipalName           = $User.userPrincipalName
            Department                  = $User.Department
            Manager                     = (Get-AzureADUserManager -ObjectId $User.UserPrincipalName).DisplayName
            JobTitle                    = $User.JobTitle
            EmployeeId                  = $User.ExtensionProperty.employeeId
            SharedMailbox               = $SharedMailbox 
            AADLogonAppUsed             = $MostRecentAADSignIn.ClientAppUsed
            AADLogonAppDisplayName      = $MostRecentAADSignIn.AppDisplayName
            AADLogonDeviceUsed          = $MostRecentAADSignIn.DeviceDetail.Displayname

        }

        $UserResultsObj = New-Object -TypeName PSObject -Property $UserProps
        $UserResultsObj | Export-Csv -NoTypeInformation -Append $outFile
        
        # Clean up variables to prevent accidental reuse
        if($AADLastLogon){Clear-Variable AADLastLogon}
        if($MostRecentSignIn){Clear-Variable MostRecentSignIn}
        if($UniversalTime){Clear-Variable UniversalTime}
        if($MailboxLogonTimestamp){Clear-Variable MailboxLogonTimestamp}
        if($MbxLastLogon){Clear-Variable MailboxLogonTimestamp}
        if($DN){Clear-Variable DN}

}



