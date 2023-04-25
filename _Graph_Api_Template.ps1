$ClientID = "xxx"
$ClientSecret = "***"
$TenantId = "***"
$Uri = 'https://graph.microsoft.com/beta/users?$select=displayName,onPremisesSamAccountName,userPrincipalName,employeeId,signInActivity,userType,accountEnabled,lastPasswordChangeDateTime,createdDateTime,signInSessionsValidFromDateTime,lastDirSyncTime,streetAddress,city,state,jobTitle,department,officeLocation,mobilePhone,phoneNumber,onPremisesImmutableId,Id,passwordPolicies,passwordProfile' 
$OutputFolder = "C:\tmp"

# Body of request
$Body = @{    
    'tenant'        = $TenantId
    'client_id'     = $ClientID
    'Scope'         = "https://graph.microsoft.com/.default"
    'client_secret' = $ClientSecret
    'grant_type'    = "client_credentials"
} 

# Parameters
$Params = @{
    'Uri' = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    'Method' = 'Post'
    'Body' = $Body
    'ContentType' = 'application/x-www-form-urlencoded'
}

# Get token
try 
{
    $Token = Invoke-RestMethod @Params
} catch {
    Write-Error "[!] Token retrieval not successful! Please check parameters and try again. Exiting..."
}

# Check if authentication was successful.
if ($Token.access_token) 
{

    Write-Host "[*] Connection successful"

    $Header = @{
        'Content-Type'  = "application\json"
        'Authorization' = "$($Token.token_type) $($Token.access_token)"
    }

    # Execute the query
    $Results = Invoke-RestMethod -Headers $Header -Uri $Uri -UseBasicParsing -Method Get -ContentType "application/json"
    
}