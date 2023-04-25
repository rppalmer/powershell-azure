# Description
# This script exports the service accounts in ADDS to a csv file

# UPN format
#$cred = Get-Credential

# Include search bases of OUs where Service Accounts reside. In cases where more than just service accounts are present, the speific CN is provided.
$SearchBases = @("CN=Managed Service Accounts,DC=Domain,DC=Local")
$DCName = "xxx"

# loop through search bases and add data to $Accounts
foreach ($SearchBase in $SearchBases)
{
    $Accounts += Get-ADUser -Credential $Cred -searchbase $SearchBase -filter * -Server $DCName -Properties DisplayName,Name,UserPrincipalName,LastLogonDate,WhenCreated,WhenChanged,DistinguishedName,Enabled   
}

# Loop through results and grab only accounts that are enabled 
foreach ($Account in $Accounts)# | Where-Object {$_.Enabled = $true})
{
    # Create SamAccountName from UPN
    # NOTE: Unfortunately this cmdlet truncates that samAccountName field so it has to be extracted from the UPN instead
    $SamAccountName = ($Account.userprincipalname -split ('@'))[0]
    
    # commas mess up csv export, convert commas to /
    $DN = $Account.DistinguishedName -replace (",","/")
    
    # Create custom object
    $UserProps = [ordered]@{
        Displayname         = $Account.DisplayName
        UserPrincipalname   = $Account.UserPrincipalName
        SamAccountName      = $SamAccountName
        LastLogonDate       = $Account.LastLogonDate
        WhenCreated         = $Account.WhenCreated
        WhenChanged         = $Account.WhenChanged
        DistinguishedName   = $DN
        AccountEnabled      = $Account.Enabled
    }

    $UserObject = New-Object -TypeName PSObject -Property $UserProps       
    $UserObject | Export-Csv -NotypeInformation -Append "c:\tmp\20201518_ADDSServiceAccount.csv"
}

#$DiffResults | Export-Csv -NotypeInformation -Append "c:\tmp\20201518_ADDSServiceAccount.csv"
Clear-Variable Accounts
Clear-Variable DiffResults