# Common AD tasks

# Check user's UPN against local active directory
function localADUserCheck 
{
    param
    (
        [Parameter(Mandatory=$true, HelpMessage='Get information for specified UPN',Position=0)]
        [string] $UPN,
        [Parameter(Mandatory=$false, Helpmessage='Target AD Servers',Position=1)]
        [string] $Server = "azuredc06.hpfc.local",
        [Parameter(Mandatory=$false, HelpMessage='Get information for all users. Assumes export',Position=2)]
        [switch] $All = $False,
        [Parameter(Mandatory=$false, HelpMessage='Provide path to save results. Default: Script Directory (CSV)',Position=3)]
        [string] $Path=$PSScriptRoot
    )

    $samAccountName = ($UPN -split "@")[0]

    if ($null -eq $cred)
    {
        Write-host "You must provide credentials before connecting"
        $cred = Get-Credential

    }
    
    if ($All -eq $True){
        
        # Create folder if it doesn't exist
        if (!(Test-Path $Path))
        {
            Write-Host ("[*] Creating folder '{0}'." -f $Path)
            $null = New-Item -ItemType Directory -Path $Path
        }

        Get-ADUser -Credential $cred -filter * -Server $Server | Select-Object userPrincipalName,enabled,passwordLastSet | `
        Export-Csv -NoTypeInformation $Path

        Write-Host ("[*] Complete. Exported to '{0}'." -f $Path)

    }else{

        try{
            Get-ADUser -Identity $samAccountName -Credential $cred -Server $Server | Select-Object userPrincipalName,enabled,passwordLastSet
        }catch{
            Write-Host ("[*] '{0}' Not Found!" -f $UPN)
        }
    }  
}
