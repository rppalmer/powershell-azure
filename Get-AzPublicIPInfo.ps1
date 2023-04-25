$ErrorActionPreference = "silentlyContinue"

Function Get-PIPInfo
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $PIP
    )
    
    # Azurespeed IP lookup
    $URL = "https://www.azurespeed.com/api/ipinfo?ipAddressOrUrl="
    Write-Host "`n`nQuerying AzureSpeed Rest API =>" $URL$PIP
    $Result = Invoke-RestMethod -uri $URL$PIP
    $Result
    

    foreach ($sub in (Get-AzSubscription | Where-Object {$_.state -eq "Enabled"}))
    {
        Select-AzSubscription -subscriptionid $sub.id | Out-Null
        $FoundPIP = Get-AzPublicIpAddress | Where-Object {$_.ipaddress -eq $PIP}
        
        if ($FoundPIP)
        {
            Write-Host "[!] Found PIP [ Name: " $FoundPIP.name " ] [ IP: " $FoundPIP.ipaddress " ] [ Subscription: " $Sub.Name " ]"
        }
    }
}
