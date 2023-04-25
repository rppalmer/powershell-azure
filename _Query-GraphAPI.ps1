$ClientID = "xxx"
$ClientSecret = "xxx"
$TenantId = "xxx"
$Uri = 'https://graph.microsoft.com/beta/subscriptions/a8737087-6097-4b7d-af8b-0c2add8f5b74/resourceGroups/log-analytics-workspace-east/providers/Microsoft.OperationalInsights/workspaces/log-analytics-workspace-east/Tables?api-version=2017-04-26-preview' 


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

###

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

###
# Get token (hash table used for splatting parameters / readability)
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

    # Create an empty array to store the result.
    $AllResults = @()

    # Execute the query
    $Results = Invoke-RestMethod -Headers $Header -Uri $Uri -UseBasicParsing -Method Get -ContentType "application/json"
    
    if ($Results.value){$AllResults += $Results.value}else{$AllResults += $Results}     

    # Page through results are until there are no more
    while($null -ne $Results.'@odata.nextLink') 
    {
        $Results = Invoke-RestMethod -Headers $Header -Uri $Results.'@odata.nextLink' -UseBasicParsing -Method Get -ContentType "application/json"
        if ($Results.value){$AllResults += $Results.value}else{$AllResults += $Results}
        
        # Avoid being throttled 
        $sleep = 3
        Write-Host "Sleeping for $sleep seconds to avoid being throttled" 
        Start-Sleep $sleep
    }

   
} else {
    Write-Error "[!] No access token! Please check parameters and try again. Exiting..."
}

$AllResults
