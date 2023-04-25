Function SetAADUserProperties
{
    Param (
        [Parameter (Mandatory= $true, HelpMessage="Provide UPN of target user (user@domain.com")]
        [string] $TargetAccount,
        [Parameter (Mandatory= $true, HelpMessage="Set account to expire True/False (Default: False)")]
        [bool] $SetToExpire = $False
    )

    # Check if string in UPN format
    if (($TargetAccount.ToCharArray()) -contains "@" -eq $False)
    {
        Write-Error "[!] Username must be in UPN format >>> user@domain.com!"
        Exit
    }

    # Set to expire/not expire depending on parameter
    switch ($SetToExpire)
    {
        $True 
        {
            $TargetUser = Get-AzureADUser -ObjectId $TargetAccount
            write-host "[*] Setting" $TargetUser.UserPrincipalName "to expire`n"
        }
        $False 
        {
            $TargetUser = Get-AzureADUser -ObjectId $TargetAccount
            write-host "[*] Setting" $TargetUser.UserPrincipalName "to *NOT* expire`n"
        }
    }
}

Write-Output "`n[*] Getting Credentials...`n"
$Credential = Get-Credential

Write-Output "[*] Authenticating to AzureAD...`n"
Connect-AzureAD -Credential $Credential | Out-Null

SetAADUserProperties -TargetAccount "xx" -SetToExpire $True