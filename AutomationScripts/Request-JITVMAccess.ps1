# Check for Az.Accounts Powershell Module
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    try {
        Install-Module -Scope CurrentUser -Name Az.Acccounts -Force -ErrorAction Stop
    } catch {
        Write-Host -ForegroundColor Red "[!] Unable to install module Az.Accounts."
        Exit
    }
}

# Check for Az.Security Powershell Module
if (-not (Get-Module -ListAvailable -Name Az.Security)) {
    try {
        Install-Module -Scope CurrentUser -Name Az.Security -Force -ErrorAction Stop
    } catch {
        Write-Host -ForegroundColor Red "[!] Unable to install module Az.Security."
        Exit
    }
}

# Check for Az.Compute Powershell Module
if (-not (Get-Module -ListAvailable -Name Az.Compute)) {
    try {
        Install-Module -Scope CurrentUser -Name Az.Compute -Force -ErrorAction Stop
    } catch {
        Write-Host -ForegroundColor Red "[!] Unable to install module Az.Compute."
        Exit
    }
}

# Import Module Az.Accounts
try {
    Import-Module -Name Az.Accounts -Force -ErrorAction Stop
} catch {
    Write-Host -ForegroundColor Red "[!] Unable to import module Az.Accounts."
    Exit
}

# Import Module Az.Security
try {
    Import-Module -Name Az.Security -Force -ErrorAction Stop
} catch {
    Write-Host -ForegroundColor Red "[!] Unable to import module Az.Security."
    Exit
}

# Import Module Az.Compute
try {
    Import-Module -Name Az.Compute -Force -ErrorAction Stop
} catch {
    Write-Host -ForegroundColor Red "[!] Unable to import module Az.Compute."
    Exit
}

$VMName = "xxx"                        # Name of VM as it appears in Azure
$Port   = 22                                        # Port to open (e.g., 22, 3389, 5986). Windows = 3389, Linux = 22
$Hours  = 2                                         # Number of hours to leave enabled (Max 3 hours)
$SubId  = "xxx"    # Retrieve the appropriate Subscription ID and update value 
$TenandId = "xxx"

# Connect to Azure and set appropriate subscription 
Connect-AzAccount -TenantId $tenantId | Out-Null
Set-AzContext -SubscriptionId $SubId -TenantId $tenantId | Out-Null

# Get VPN IP
$VpnIp = ((ipconfig | findstr [0-9].\.)[0]).split()[-1]

# Get details about VM
$VMDetails = Get-AzVM -Name $VMName | Select-Object Id, ResourceGroupName, Location

# End time in UTC
$EndTime  = ((Get-Date).AddHours($Hours)).ToUniversalTime().Tostring("yyyy-MM-ddTHH:mm:ss.fffffffZ")

$JitPolicy = (@{
    id=$VMDetails.Id;
    ports=(@{
       number=$Port;
       endTimeUtc=$EndTime;
       allowedSourceAddressPrefix=@($VpnIp)
    })
})

Start-AzJitNetworkAccessPolicy -ResourceGroupName $($VMDetails.ResourceGroupName) -Location $VMDetails.Location  -Name "default" -VirtualMachine $JitPolicy