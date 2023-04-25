# Export a list of Azure VMs including private IP address from all subscriptions

$timestamp = Get-Date -UFormat "%Y%m%d"
$Path = "C:\tmp\"+$timestamp+"_linuxVMs.csv"

function CheckProvider
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $provider,
        [Parameter(Mandatory=$true, Position=1)]
        [array] $ProviderList
    )

    $GetProviderInfo = $ProviderList | Where-Object {$_.ProviderNamespace -eq $provider}

    If ($GetProviderInfo.RegistrationState -eq "Registered")
    {
        return $true
    }else {
        return $false
    }  

    Clear-Variable GetProviderInfo
}

# function to use for threading?
# function GetObjects
# {
#     param(

#     )
# }

# Loop through each enabled Azure Subscription
$VMObjArray = @()
Foreach ($Sub in (Get-AzSubscription | Where-Object {$_.state -eq "Enabled"} ))
{
    # Select next sub
    Select-AzSubscription -Subscriptionid $Sub.id | out-null

    # Get list of providers
    try
    {
        $Providers = Get-AzResourceProvider -ListAvailable
    }catch{
        "subscription in a state that prevents provider listing"
    }

    # If providerlist is empty, skip
    If ($Providers)
    {
        $ProviderName = "Microsoft.Compute"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {

            # Get a list of all network adapters in sub
            $NICs = Get-AzNetworkInterface

            # Get Running Non-Citrix Windows VMs
            #$VMs = Get-AzVM -status | Where-Object {$_.PowerState -match "VM Running" -and $_.StorageProfile.OsDisk.OsType -match "Windows" -and $_.ResourceGroupName -notmatch "citrix-xd*" -and $_.ResourceGroupName -notmatch "BPO_*" }
            
            # Get All Running Windows VMs
            $VMs = Get-AzVM -status | Where-Object {$_.StorageProfile.OsDisk.OsType -notmatch "Windows"}

            # Get All Running Non-Windows VMs
            # $VMs = Get-AzVM -status | Where-Object {$_.PowerState -match "VM Running" -and $_.StorageProfile.OsDisk.OsType -notmatch "Windows"}

            # Get All Running VMs
            # $VMs = Get-AzVM -status | Where-Object {$_.PowerState -match "VM Running"}

            # Get All VMs
            # $VMs = Get-AzVM -status

            Foreach ($VM in $VMs)
            {

                # Correlate network adapter
                $VMNic = $NICs | Where-Object {$_.id -eq $VM.NetworkProfile.NetworkInterfaces.id}

                # Create object properties
                $VMProps = [ordered]@{
                    Name            = $VM.Name
                    PowerState      = $VM.PowerState
                    RGName          = $VM.ResourceGroupName
                    ipAddress       = $VMNic.IpConfigurations.privateipaddress
                    OS              = $VM.StorageProfile.OsDisk.OsType
                    Subscription    = $Sub.Name
                }
            
                # Create object, add properties
                $VMObj = New-Object -TypeName PSObject -Property $VMProps
                $VMObjArray += $VMObj

            }
        }else{
            write-host "Skipped ${Sub}.name due to lack of necessary provider"
        }
    }else{
        write-host "Skipped ${Sub}.name due to lack of necessary provider"
    }
    clear-variable Providers
}

# Export results to CSV
$VMObjArray | Export-Csv -NoTypeInformation -Append $Path