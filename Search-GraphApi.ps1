<#
.SYNOPSIS
    Query Graph API
.DESCRIPTION
    Function to query Graph API
.PARAMETER ClientId
    Required.  Client Id of the service principal
.PARAMETER ClientSecret
    Required.  Service Principal Client Secret
.PARAMETER TenantId
    Required.  Azure AD Tenant ID
.PARAMETER Uri
    Required. Uri / Graph API query
.PARAMETER OutputFolder
    Optional. Folder to store csv output. Default: Script Directory
.EXAMPLE 
    Get-GraphApiResult -ClientID 0abcd5cb-7fff-0123-a999-0000bb4d9a54 -TenantId 123fadee-12c9-1234-123d-45678c6f09bb -ClientSecret "1ab123-456ab78d-AaaA-asd7asd890j" -Uri 'https://graph.microsoft.com/beta/users' -OutputFolder C:\tmp
.NOTES
    Import-Module .\Search-GraphApi.ps1"

#>
function Search-GraphAPI {

    param (
        [parameter(Mandatory=$true, HelpMessage='Service Principal Client Id')]
        [string]$ClientID,
        [parameter(Mandatory=$true, HelpMessage='Service Principal Client Secret')]
        [string]$ClientSecret,
        [parameter(Mandatory=$true, HelpMessage='Azure AD Tenant ID')]
        [string]$TenantId,
        [parameter(Mandatory=$true, HelpMessage='Uri / Graph API query')]
        [string]$Uri,
        [parameter(Mandatory=$false, HelpMessage='Folder to store csv output. Default Scriptroot')]
        [string]$OutputFolder=$PSScriptRoot
    )

    # If uri contains $ add backtick to escape
    $uri = ($uri).replace('\$',"`$")

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

        Write-host "[*] Connection successful"
        
        $Header = @{
            'Content-Type'  = "application\json"
            'Authorization' = "$($Token.token_type) $($Token.access_token)"
        }

        # Create an empty array to store the result.
        $AllResults = @()

        # Execute the query
        $Results = Invoke-RestMethod -Headers $Header -Uri $Uri -UseBasicParsing -Method Get -ContentType "application/json"
        
        # Add results to array
        if ($Results.value){$AllResults += $Results.value}else{$AllResults += $Results}     

        # Page through results until there are none left
        while($null -ne $Results.'@odata.nextLink') 
        {
            # Get next page of results
            $Results = Invoke-RestMethod -Headers $Header -Uri $Results.'@odata.nextLink' -UseBasicParsing -Method Get -ContentType "application/json"
            
            # Add results to array
            if ($Results.value){$AllResults += $Results.value}else{$AllResults += $Results}
            
            # Avoid being throttled 
            Start-Sleep 3
        }

        # Return the result.
        $timestamp = Get-Date -UFormat "%Y%m%d"
        $outFile = $OutputFolder+"\"+$timestamp+"_queryresults.csv"
        $AllResults | Export-Csv -NoTypeInformation -Append $outFile

    } else {
        Write-Error "[!] No access token! Please check parameters and try again. Exiting..."
    }
}