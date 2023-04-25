#$cred = Get-Credential

# Include search bases of OUs where Service Accounts reside. In cases where more than just service accounts are present, the speific CN is provided.
$SearchBases = @("")

# SamAccountNames taken from service account review spreadsheet "Version 5_28_2021 of the Service Account and Automation Process Inventory_RL (003)"
$ExcludedSamAccountNames = ("")

foreach ($SearchBase in $SearchBases)
{
    $Accounts += Get-ADUser -Credential $Cred -searchbase $SearchBase -filter * -Server azuredc06.hpfc.local -Properties DisplayName,Name,UserPrincipalName,LastLogonDate,WhenCreated,WhenChanged,DistinguishedName,Enabled
    
}

$DiffResults = @()
# Loop through results and grab only accounts that are enabled and don't exist in spreadsheet
foreach ($Account in $Accounts )#| Where-Object {$_.Enabled = $True})
{
    # Create SamAccountName from UPN
    $SamAccountName = ($Account.userprincipalname -split ('@'))[0]
    
    # only proceed if name not in samaccountname array
    if ($SamAccountName -notin $ExcludedSamAccountNames -and $Account.UserPrincipalName -notin $ExcludedSamAccountNames)
    {
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
        $DiffResults += $UserObject
    }
}

$DiffResults | Export-Csv -NotypeInformation -Append "c:\tmp\20200830_ADDSServiceAccountDiff.csv"
Clear-Variable Accounts
Clear-Variable DiffResults