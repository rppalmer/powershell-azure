<# 
.SYNOPSIS 
    Script for rotating passwords on local account for Windows machines and storing them in Hashicorp Vault.
.DESCRIPTION 
    The script authenticates to vault, generates a new passwords, and stores it in vault. If for some reason
    the script fails to store the password in vault the local password remains unchanged as a safeguard.
.NOTES   
    Version:        4.0 
    Author:         Ryan Palmer / Sean Cooper
    Creation Date:  4/22/2020
    Purpose/Change: Added additional checks for environment variables and changed sendgrid_api to environment variable

    IMPORTANT:
    Make sure VAULT_PW, VAULT_ADDR, and SENDGRID_API are stored as environment variables or script will not run
#> 

# Check for correct usage
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$USERNAME
)

####################
### Log Function ###
####################
Function logger
{
    param
    (
        [Parameter(Mandatory=$false, Position=1)]
        [string] $logMessage
    )
    $timestamp = Get-Date -UFormat "%Y%m%dT%I%M%S"
    $logPath = Join-Path $PSScriptRoot "rotate-passwords.log"
    "$timestamp : $logMessage" | out-file -NoClobber -Append $logPath
}

logger -logMessage "Starting run..."

####################################
### Variable and username checks ###
####################################

# set correct timezone
Set-TimeZone -Name "US Eastern Standard Time"

$HOSTNAME = $env:computername
$VAULT_PW = $env:VAULT_PW
$VAULT_ADDR = $env:VAULT_ADDR
$SENDGRID_API = $env:SENDGRID_API
$destEmailAddress = "username@domain.com"
$fromEmailAddress = "username@domain.com"

# Make sure the user exists on the local system.
if (-not (Get-LocalUser $USERNAME)) {
    logger -logMessage "$USERNAME does not exist!"
    throw '$USERNAME does not exist!'
}

# Make sure $VAULT_ADDR is not empty
if (!$VAULT_ADDR) {
    $message = "VAULT_ADDR environment variable not defined!"
    logger -logMessage $message
    sendMail -content $message -subject "VAULT_ADDR environment variable not defined! - ${hostname}" 
    throw $message
}

# Make sure $VAULT_PW is not empty
if (!$VAULT_PW) {
    $message = "VAULT_PW environment variable not defined!"
    logger -logMessage $message
    sendMail -content $message -subject "VAULT_PW environment variable not defined! - ${hostname}" 
    throw $message
}

# Make sure $SENDGRID_API is not empty
if (!$SENDGRID_API) {
    $message = "SENDGRID_API  environment variable not defined!"
    logger -logMessage $message
    sendMail -content $message -subject "SENDGRID_API  environment variable not defined! - ${hostname}" 
    throw $message
}

# Use TLS
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Ignore self-signed certs
function Ignore-SelfSignedCerts
{
    Add-Type -TypeDefinition  @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy
    {
        public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,                                                                                                                                 
        WebRequest request, int certificateProblem)
        {
            return true;
        }
    }   
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
}

Ignore-SelfSignedCerts

######################
### Email Function ###
######################

Function sendMail
{
    param
    (
        [Parameter(Mandatory=$false, Position=0)]
        [string] $content, 
        [Parameter(Mandatory=$false, Position=1)]
        [string] $subject
    )
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer " + $SENDGRID_API)
    $headers.Add("Content-Type", "application/json")
    $body = @{
    personalizations = @(
        @{
            to = @(
                    @{
                        email = $destEmailAddress
                    }
            )
        }
    )
    from = @{
        email = $fromEmailAddress 
    }
    subject = $subject
    content = @(
        @{
            type = "text/html"
            value = $content
        }
    )
    }
    $bodyJson = $body | ConvertTo-Json -Depth 4
    Invoke-RestMethod -Uri https://api.sendgrid.com/v3/mail/send -Method Post -Headers $headers -Body $bodyJson
}

#####################################
### Prereqs for Password Rotation ###
#####################################

# Authenticate to vault with userpass and generate a token. Token will be used to generate 
# and write passwords to vault
$VAULT_TOKEN = (Invoke-RestMethod -Method Post -uri ${VAULT_ADDR}/v1/auth/userpass/login/pwrotatesvc `
-Body "{`"password`":`"$VAULT_PW`",`"period`":`"24h`",`"policies`":`"rotate-linux`"}" | Select-Object `
-expand auth).client_token

# Fetch a new "passphrase" from Vault. Adjust the options to fit your requirements.
#$NEWPASS = (Invoke-RestMethod -Headers @{"X-Vault-Token" = ${VAULT_TOKEN}} -Method Post `
# -Body "{`"words`":`"4`",`"separator`":`"-`"}" -Uri ${VAULT_ADDR}/v1/gen/passphrase).data.value

# Fetch a new "password" from Vault. Adjust the options to fit your requirements.
$NEWPASS = (Invoke-RestMethod -Headers @{"X-Vault-Token" = ${VAULT_TOKEN}} -Method Post `
-Body "{`"length`":`"36`",`"symbols`":`"0`"}" -Uri ${VAULT_ADDR}/v1/gen/password).data.value

# Convert into a SecureString for use with setting local password
$SECUREPASS = ConvertTo-SecureString $NEWPASS -AsPlainText -Force

# Create the JSON payload to write to Vault's K/V store. Keep the last 12 versions of this credential.
$JSON="{ `"options`": { `"max_versions`": 12 }, `"data`": { `"$USERNAME`": `"$NEWPASS`" } }"


#######################
### Rotate Password ###
#######################

# First commit the new password to vault, then change it locally.
Invoke-RestMethod -Headers @{"X-Vault-Token" = ${VAULT_TOKEN}} -Method Post `
-Body $JSON -Uri ${VAULT_ADDR}/v1/systemcreds/data/windows/${HOSTNAME}/${USERNAME}_creds

if($?) {
    Write-Output "Vault updated with new password."
    $UserAccount = Get-LocalUser -name $USERNAME
    $UserAccount | Set-LocalUser -Password $SECUREPASS
    if($?) {
        $message = "${USERNAME}'s password was stored in Vault and updated locally."
        Write-Output $message
        logger -logMessage $message
    }
    else {
        $message = "Error: ${USERNAME}'s password was stored in Vault but *not* updated locally."
        Write-Output $message
        logger -logMessage $message
        sendMail -content $message -subject "Password rotation error for: ${hostname}" 
    }
}
else {
    $message = "Error saving new password to Vault. Local password for ${USERNAME} will remain unchanged"
    Write-Output $message
    logger -logMessage $message
    sendMail -content $message -subject "Password rotation error for: ${hostname}" 
}