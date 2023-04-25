#Connect-AzureAD

$PathCsv = "C:\tmp\EnterpriseApplicationReport.csv"
#$WorkspaceId = 'xxx'

# # Convert timestamp
# function Convert-TimeStamp
# {
#     param
#     (
#         [Parameter(Mandatory=$true, Position=0)]
#         [string] $TimeObject,
#         [Parameter(Mandatory=$false, Position=1)]
#         [string] $TimeZone = 'Eastern Standard Time'
#     )

#     $UniversalTime = ([DateTime]$TimeObject).ToUniversalTime()
#     [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($UniversalTime, $TimeZone)

# }

# Get a list of all Service Principals
#$ServicePrincipalList = Get-AzureADServicePrincipal -All $true
$ServicePrincipalList = Get-AzureADServicePrincipal -all $true | Select-Object ObjectId,ObjectType,AccountEnabled,DisplayName,Tags,PublisherName,ReplyURLs,SamlMetadataUrl,ServicePrincipalNames,ServicePrincipalType,Appid

# # Get AADSP Logons
# $QSPSignInData = @"
# let days = 365d;
# AADServicePrincipalSignInLogs
# | where TimeGenerated > ago(days)
# | summarize arg_max(TimeGenerated,*) by ServicePrincipalName
# | project ServicePrincipalName,TimeGenerated
# "@

# # Get ManagedID logons
# $QMgIdSignInData = @"
# let days = 365d;
# AADManagedIdentitySignInLogs
# | where TimeGenerated > ago(days)
# | summarize arg_max(TimeGenerated,*) by ServicePrincipalName
# | project ServicePrincipalName,TimeGenerated
# "@

# # Merge Sign-in Data
# $SignInData  =  (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $QSPSignInData).Results 
# $SignInData  +=  (Invoke-AzOperationalInsightsQuery -WorkspaceId $WorkspaceID -Query $QMgIdSignInData).Results 

# Loop through each and get assignment information, create custom object
foreach($ServicePrincipal in $ServicePrincipalList){
   
    # # Map SP
    # $SPSignInData = $SignInData | Where-Object {$_.ServicePrincipal -eq $ServicePrincipal.DisplayName}

    
    # # Convert Azure Active Directory Sign-in Timestamp to Eastern, skip if no time stamp
    # Try{
    #     $SPLastLogonTimestamp = Convert-TimeStamp -TimeObject $SPSignInData.TimeGenerated
    # } Catch {
    #     $SPLastLogonTimestamp = "not available"
    # }

    # Get role assignments
    $SPAssignments += Get-AzureADServiceAppRoleAssignment -ObjectId $ServicePrincipal.objectId 
    
    # store user assignments, semi-colon delimited, in variable
    foreach ($SPAssignment in $SPAssignments){$AppAssignments += $SPAssignment.PrincipalDisplayName + "; "}

    # Create custom object to hold the data
    $SPProps = [ordered]@{
        DisplayName             = $ServicePrincipal.DisplayName
        Tier                    = ""
        Wave                    = ""
        GeneralType             = ""
        Category                = ""
        Tags                    = $ServicePrincipal.Tags -join "; "
        LastLoginTimestamp      = $SPLastLogonTimestamp
        ServicePrincipalType    = $ServicePrincipal.ServicePrincipalType
        AccountEnabled          = $ServicePrincipal.AccountEnabled
        PublisherName           = $ServicePrincipal.PublisherName
        ReplyURLs               = $ServicePrincipal.ReplyURLs -join "; "
        ServicePrincipalNames   = $ServicePrincipal.ServicePrincipalNames -join "; "
        ObjectId                = $ServicePrincipal.ObjectId
        ObjectType              = $ServicePrincipal.ObjectType     
        SamlMetadataUrl         = $ServicePrincipal.SamlMetadataUrl
        ApplicationId           = $ServicePrincipal.AppId
        Assignments             = $AppAssignments 
        Notes                   = ""
    }
    
    $SPObject = New-Object -TypeName PSObject -Property $SPProps
    $SPObject | Export-Csv -Append -NoTypeInformation "C:\tmp\20220519_EnterpriseAppExport.csv"
    
    # Clean up
    Clear-Variable AppAssignments
    Clear-Variable SPAssignments
}