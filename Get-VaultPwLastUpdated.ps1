<# 
.SYNOPSIS 
    Script for checking latest password timestamp for vault
.DESCRIPTION 
    The script authenticates to vault with a token, loops through all the entries, and
    gets latest timestamp.
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  4/29/2020
    Purpose/Change: Initial script creation
#> 

### Standard Connection code for Azure Runbooks ###
$connection = Get-AutomationConnection -Name AzureRunAsConnection
Connect-AzAccount -ServicePrincipal `
                -Tenant $connection.TenantId `
                -ApplicationID $connection.ApplicationId `
                -CertificateThumbprint $connection.CertificateThumbprint
$AzureContext = Select-AzSubscription -SubscriptionId "xxx"

$VAULT_ADDR='https://vaulthostname:8200'
$VAULT_PW = (Get-AzKeyVaultSecret -VaultName "xxx-kv" -Name "xxx").SecretValueText

### Set Timezone to Eastern ###
Set-TimeZone -Name "US Eastern Standard Time"

### Authenticate to vault with user/pass to get token ###
$VAULT_TOKEN=(curl.exe -sS -k --fail -X POST -H "Content-Type: application/json" --data "{\`"password\`": \`"$VAULT_PW\`",\`"period\`":\`"24h\`",\`"policies\`":\`"rotate-password\`"}" `
$VAULT_ADDR/v1/auth/userpass/login/pwrotatesvc -k | jq -r '.auth.client_token')

$all_results = @()
### loop through windows vault host entries (and trim unneeded characters) ###

foreach ($os in ((curl.exe -sS -k -X LIST "${VAULT_ADDR}/v1/systemcreds/metadata" -H "X-Vault-Token: $VAULT_TOKEN" | jq '.data.keys | .[]') -replace'[\/,\",]', ''))
{
    foreach ($hostname in ((curl.exe -sS -k -X LIST "${VAULT_ADDR}/v1/systemcreds/metadata/$os" -H "X-Vault-Token: $VAULT_TOKEN" | jq '.data.keys | .[]') -replace'[\/,\",]', ''))
    {
        foreach ($credential in ((curl.exe -sS -k  -X LIST "${VAULT_ADDR}/v1/systemcreds/metadata/$os/$hostname" -H "X-Vault-Token: ${VAULT_TOKEN}" | jq '.data.keys | .[]') -replace'[\/,\",]', ''))
        {
            
            $timestamp = $(curl.exe -sS -k  -X GET "${VAULT_ADDR}/v1/systemcreds/metadata/$os/$hostname/$credential" -H "X-Vault-Token: ${VAULT_TOKEN}" | jq -r '.data.updated_time')

            $tmp_result = "" | Select-Object  hostname, ostype, credential, lastupdate
            $tmp_result.hostname = $hostname
            $tmp_result.credential = $credential
            $tmp_result.lastupdate = $timestamp
            $tmp_result.ostype = $os
            $all_results += $tmp_result
        }
    }
}

$all_results | Export-Csv c:\tmp\checkvpw.csv

# might need this later if we need to convert string to datetime object for comparison
# ([system.datetime]::ParseExact($creationtime, "yyyy-MM-ddTH:mm:ss.FFFFFFFFFFK", $null).tostring('yyyy-MM-ddTH:mm:ss.FFFFFFFK')) 