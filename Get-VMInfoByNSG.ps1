# There are two scenarios where a VM could be attached (both could apply)
# 1) Directly 
# 2) Associated with a subnet where the NSG is attached

# Get NSG information including subscription
$NSGName = "nsgname"
$NSGInfo = Search-AzGraph -first 1000 -Query "resources | where type =~ 'Microsoft.Network/NetworkSecurityGroups' and name contains '$NSGname'"
$Subscription = ($NSGInfo.ResourceId -split "/")[2]
$Subnets = (Get-AzNetworkSecurityGroup -name $NSGName).Subnets.id
Set-AzContext -Subscription $Subscription | Out-Null

# Loop through network configurations and determine VM attached to subnet with NSG, or directly attached to NSG
foreach ($NIC in Get-AzNetworkInterface)
{
    # If subnet equals target NSG's subnet
    if ($NIC.IpConfigurations.subnet.id -in $Subnets -or ($NIC.NetworkSecurityGroup.id -split "/")[-1] -eq $NSGName)
    {
        # Check for public IP
        if ($NIC.IpConfigurations.PublicIpAddress){
            $PublicIP = (Get-AzPublicIpAddress -Name ($NIC.IpConfigurations.PublicIpAddress.id -split "/")[-1]).IPAddress
        }else{
            $PublicIP = "n/a"
        }

        # Get network details
        $SubnetName = ($NIC.IpConfigurations.subnet.id -split "/")[-1]
        $VirtualNetName = ($NIC.IpConfigurations.subnet.id -split "/")[-3]
        
        # If no attached VM
        if (!$NIC.VirtualMachine.id)
        {
            $VMProps = [ordered]@{
                NICName             = $NIC.Name
                NICResourceGroup    = $NIC.ResourceGroupName
                Subnet              = $SubnetName
                VirtualNet          = $VirtualNetName
                PrivateIP           = $NIC.IpConfigurations.PrivateIpAddress
                PublicIP            = $PublicIP
                NSGName             = $NSGName
                VMName              = "n/a"
                VMResourceGroup     = "n/a"
                PowerState          = "n/a"
                Location            = "n/a"
                OperatingSystem     = "n/a"
                Subscription        = (Get-AzSubscription -SubscriptionId ($NIC.id -split "/")[2]).name
            }
            
            $VMResultsObj = New-Object -TypeName PSObject -Property $VMProps
            $VMResultsObj | export-csv -NoTypeInformation -Append "c:\tmp\nsgreview.csv"

            Clear-Variable SubnetName
            Clear-Variable VirtualnetName

        # If VM attached
        }else{
            # If network configuration subnet matches desired NSG Subnet
            $VMName = ($NIC.VirtualMachine.id -split "/")[-1]
            $AttachedVM = Get-AzVM -name $VMName -Status
            
            $VMProps = [ordered]@{
                NICName             = $NIC.Name
                NICResourceGroup    = $NIC.ResourceGroupName
                Subnet              = $SubnetName
                VirtualNet          = $VirtualNetName
                PrivateIP           = $NIC.IpConfigurations.PrivateIpAddress
                PublicIP            = $PublicIP
                NSGName             = $NSGName
                VMName              = $AttachedVM.Name
                VMResourceGroup     = $AttachedVM.ResourceGroupName
                PowerState          = $AttachedVM.PowerState
                Location            = $AttachedVM.Location
                OperatingSystem     = $AttachedVM.storageprofile.osdisk.ostype
                Subscription        = (Get-AzSubscription -SubscriptionId ($NIC.id -split "/")[2]).name
            }
            
            $VMResultsObj = New-Object -TypeName PSObject -Property $VMProps
            #$VMResultsArr += $VMResultsObj
            $VMResultsObj | export-csv -NoTypeInformation -Append "c:\tmp\nsgreview.csv"

            Clear-Variable VMName
            Clear-Variable AttachedVM

        }
    }

    Clear-Variable SubnetName
    Clear-Variable VirtualnetName
    Clear-Variable PublicIP
}