<# 
.SYNOPSIS 
    Menu-driven front-end to request JIT VM Access
.DESCRIPTION 
    Provides a way to search for VMs and request JIT VM access through a menu.
.NOTES   
    Version:        2.0 
    Author:         Ryan Palmer
    Creation Date:  4/27/2022
    Updated:        6/15/2022
#>
$tenantId = "xx"
function Show-Menu {

   Clear-Host
   $Title =@'
   #                              # ### ####### 
  # #   #    # #####  ####        #  #     #    
 #   #  #    #   #   #    #       #  #     #    
#     # #    #   #   #    #       #  #     #    
####### #    #   #   #    # #     #  #     #    
#     # #    #   #   #    # #     #  #     #    
#     #  ####    #    ####   #####  ###    #    
                                        v2
'@
    
    Write-Host -ForegroundColor Blue "************************************************"      
    Write-host -ForegroundColor Blue $Title
    Write-Host -ForegroundColor Blue "************************************************" 
    Write-host ""
    Write-Host -ForegroundColor Gray "C. Press 'C' to connect to Azure"
    Write-Host -ForegroundColor Gray "S. Press 'S' to search for a VM and activate JIT"
    Write-Host -ForegroundColor Gray "R. Press 'R' to change request time (Current: $Hours hours)"
    Write-Host -ForegroundColor Gray "Q. Press 'Q' to quit."
    Write-host ""
}

function Request-JIT
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $VMname,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $VMId,
        [Parameter(Mandatory=$true, Position=2)]
        [string] $ResGroupName,
        [Parameter(Mandatory=$true, Position=3)]
        [string] $OS,
        [Parameter(Mandatory=$true, Position=4)]
        [string] $Location,
        [Parameter(Mandatory=$true, Position=5)]
        [string] $Hours,
        [Parameter(Mandatory=$true, Position=6)]
        [string] $SubId
    )


    # if OS windows, 3389 if OS linux, 22
    If ($OS -match "Windows")
    {
        $Port = 3389
        Write-Host "[*] OS Detected as Windows..."
    }elseif ($OS -match "linux") {
        $Port = 22
        Write-Host "[*] OS Detected as Linux..."
    }else{
        Write-Error "Unable to determine OS type"
        Exit
    }

    Set-AzContext $SubId -TenantId $tenantId| Out-Null
    Write-Host "[*] Connected to $Subid"

    # Get VPN IP
    $VpnIp = ((ipconfig | findstr [0-9].\.)[0]).split()[-1]
    Write-Host "[*] Retrieved VPN IP: $VpnIp"

    # End time in UTC
    $EndTime  = ((Get-Date).AddHours($Hours)).ToUniversalTime().Tostring("yyyy-MM-ddTHH:mm:ss.fffffffZ")

    $JitPolicy = (@{
        id=$VMid;
        ports=(@{
        number=$Port;
        endTimeUtc=$EndTime;
        allowedSourceAddressPrefix=@($VpnIp)
        })
    })

    Start-AzJitNetworkAccessPolicy -ResourceGroupName $ResGroupName -Location $Location  -Name "default" -VirtualMachine $JitPolicy
    Write-Host "[*] Just-in-Time activated for $VMname on port $port for $hours hour(s)"
}

function Search-VM {
    param (
        [string]$VMName,
        [int]$Hours
    )

    $Results = Search-AzGraph -first 1000 -Query "resources | where type =~ 'Microsoft.Compute/VirtualMachines' and name contains '$VMname' | extend OSType=tostring(properties.storageProfile.osDisk.osType)"

    # Generate menu based on results
    $Menu = @{}
    for ($i=1;$i -le ($Results.Name).Count; $i++) {
        Write-Host "$i. $($Results[$i-1].name)"
        $Menu.Add($i,($Results[$i-1].name))
    }

    # Add option to quit
    write-host "Q. Go back to the main menu."
    Write-host ""
    $Menu.Add("Q","Quit")
    
    # Read in answer
    $Answer = Read-Host 'Type in the VM number to Request JIT Access'

    # Invalid selection
    if ($Answer -ne "Q" -and [int]$Answer -gt $Menu.Count)
    {
        Write-Host -ForegroundColor Red "Invalid selection"
        Break
    }

    # Quit or proceed
    if ($Answer -eq "Quit" -or $Answer -eq "Q"){
        Continue
    }else{
        [int]$Answer = $Answer
        $Selection = $Menu.Item([int]$Answer)
    }

    # Request JIT
    $VMSelection = $Results | Where-Object {$_.name -eq $Selection}
    Request-JIT -VMname $VMSelection.Name -OS $VMSelection.OsType -SubId $VMSelection.SubscriptionId -Location $VMSelection.Location -ResGroupName $VMSelection.ResourceGroup -VMId $VMSelection.Id -Hours $Hours

}

# Check for the Az.Resource Module, and install if not already available
if (-not (Get-Module -ListAvailable -Name Az.ResourceGraph)) {
    try {
        Write-Host -ForegroundColor Blue "[!] Az.ResourceGraph not found, attempting to install..."
        Install-Module -Scope CurrentUser -Name Az.ResourceGraph -Force
    } catch {
        Write-Error $_.Exception.Message;
        Write-Host -ForegroundColor Red "[!] Unable to install module Az.ResourceGraph."
        Exit
    }
};

do
 {
    $Hours = 3 # Default and most likely, the max.
    Show-Menu
    $selection = Read-Host "Make a selection"
    switch ($selection)
    {
        'C' # Connect to Azure
        {
            Connect-AzAccount -Tenant $tenantId
            Set-AzContext -TenantId $tenantId
        }
        'S' # Search VM
        {
        $Request = Read-host "To Search, type in the first few letters of the VM name"
        Write-Host ""
        Search-VM -VMName $Request -Hours $Hours
        }
        'R' # Change Request Time
        {
        $Hours = Read-host "Change request duration"
        if ([int]$Hours -gt 24)
        {
            Write-Host -ForegroundColor Red "Invalid Selection"; $Hours
            Break
        }else{
            Write-Host -ForegroundColor Red "ATTENTION: The MAX request time is 3 hours. If an exception has not been"
            Write-Host -ForegroundColor Red "           submitted you'll receive an error when submitting JIT request."
            Write-Host "Request duration changed to $hours hour(s)."
            Write-Host ""
        }
        pause
        Show-Menu
        }
    }
    Pause
 }
 until ($selection -eq 'Q')