<# 
.SYNOPSIS 
    Exports NSG rules for all Subnets,Nics for all subscriptions
.DESCRIPTION 
    Exports NSG rules for all Subnets,Nics for all subscriptions
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  3/20/2021
    Purpose/Change: Initial script development

#> 

# Connect with Managed Identity
Connect-AzAccount -Identity

$timestamp = Get-Date -UFormat "%Y%m%d"
$ExportPath = "C:\Exports\NSGRules\"+$timestamp+"_VMNSGRules.csv"

Foreach ($Sub in (Get-AzSubscription | Where-Object {$_.state -eq "Enabled"} ))
{
    
    Select-AzSubscription -Subscriptionid $Sub.id | out-null

    $PIPs = Get-AzPublicIpAddress
    $VMs = Get-AzVM -Status | Select-Object Name, ResourceGroupName, PowerState, Location, NetworkProfile 
    #$VMs = Get-AzVM 
    $NICs = Get-AzNetworkInterface
    $NSGs = Get-AzNetworkSecurityGroup
    $Subnets += foreach ($VNet in (Get-AzVirtualnetwork)){Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNet}  

    # Loop through VMs
    foreach ($VM in $VMs)
    {
        # Get one or more linked network adapters
        foreach ($VMNIC in $VM.networkprofile.networkinterfaces)
        {   
            
            # Get the corresponding network adapter object
            Clear-Variable LinkedNIC; 
            $LinkedNIC = $NICs | Where-Object {$_.id -eq $VMNIC.id}

            # loop through each network adapters IP configuration (they may have more than one)
            foreach ($LinkedNICConfig in $LinkedNIC.ipconfigurations)
            {
                
                # If public IP address block exists, get additional info and if not indicate that instead
                Clear-Variable LinkedPIP;Clear-Variable PIPAddress;Clear-Variable PIPName
                If ($null -ne $LinkedNICConfig.PublicIPAddress)
                {
                    # Get PIP object linked to network interface (IP address and other information not listed directly on network interface)
                    $LinkedPIP = $PIPs | Where-Object {$_.id -eq $LinkedNICConfig.PublicIPAddress.id}
                    $PIPName = $LinkedPIP.Name
                    $PIPAddress = $LinkedPIP.IpAddress
                }else {
                    $PIPName = "No Public IP Assigned"
                    $PIPAddress = "No Public IP Assigned"
                }

                # Get the VM subnet
                Clear-Variable VMSubnet;
                foreach ($Subnet in $Subnets)
                {
                    if ($Subnet.ipconfigurations.id -eq $LinkedNICConfig.id){$VMSubnet = $Subnet}
                }

                # Get VM subnet NSG rules
                Clear-Variable SubnetNSG
                $SubnetNSG = $NSGs | Where-Object {$_.id -eq $VMSubnet.NetworkSecurityGroup.id}
                
                # If default and custom security rules exist, capture both rulesets
                if ($SubnetNSG.DefaultSecurityRules -and $SubnetNSG.SecurityRules)
                {
                    # Default
                    foreach ($Rule in $SubnetNSG.DefaultSecurityRules)
                    {
                        $SubnetNSGProps = [ordered]@{
                            VMName          = $VM.Name
                            VMResourceGrp   = $VM.ResourceGroupName
                            VMState         = $VM.PowerState
                            Location        = $VM.location
                            LinkedNICName   = $LinkedNIC.Name
                            NICIPConfigName = $LinkedNICConfig.name
                            LinkedNICIP     = $LinkedNICConfig.privateipaddress 
                            PIPName         = $PIPName
                            PIPAddress      = $PIPAddress
                            SubnetName      = $VMSubnet.Name     
                            Subscription    = $Sub.Name
                            NSGAttached     = "Subnet"
                            NSGName         = $SubnetNSG.Name
                            RuleName        = $Rule.Name
                            Protocol        = $Rule.Protocol
                            Direction       = $Rule.Direction
                            Source          = $Rule.SourceAddressPrefix -join ";"
                            SourcePortRange = $Rule.SourcePortRange -join ";"
                            Destination     = $Rule.DestinationAddressPrefix -join ";"
                            DestPortRange   = $Rule.DestinationPortRange -join ";"
                            Access          = $Rule.Access
                            Priority        = $Rule.Priority
                            LinkType        = "SubnetNSG (Default Rules)"
                        }

                        $SubnetNSGObj = New-Object -TypeName PSObject -Property $SubnetNSGProps
                        $SubnetNSGObj | Export-Csv -Append -NoTypeInformation $ExportPath
                        
                        # Cleanup
                        Clear-Variable Rule
                        Clear-Variable SubnetNSGObj
                    }
                    
                    # Custom
                    foreach ($Rule in $SubnetNSG.SecurityRules)
                    {
                        $SubnetNSGProps = [ordered]@{
                            VMName          = $VM.Name
                            VMResourceGrp   = $VM.ResourceGroupName
                            VMState         = $VM.PowerState
                            Location        = $VM.location
                            LinkedNICName   = $LinkedNIC.Name
                            NICIPConfigName = $LinkedNICConfig.name
                            LinkedNICIP     = $LinkedNICConfig.privateipaddress
                            PIPName         = $PIPName
                            PIPAddress      = $PIPAddress
                            SubnetName      = $VMSubnet.Name     
                            Subscription    = $Sub.Name
                            NSGAttached     = "Subnet"
                            NSGName         = $SubnetNSG.Name
                            RuleName        = $Rule.Name
                            Protocol        = $Rule.Protocol
                            Direction       = $Rule.Direction
                            Source          = $Rule.SourceAddressPrefix -join ";"
                            SourcePortRange = $Rule.SourcePortRange -join ";"
                            Destination     = $Rule.DestinationAddressPrefix -join ";"
                            DestPortRange   = $Rule.DestinationPortRange -join ";"
                            Access          = $Rule.Access
                            Priority        = $Rule.Priority
                            LinkType        = "SubnetNSG (Custom Rules)"
                        }

                        $SubnetNSGObj = New-Object -TypeName PSObject -Property $SubnetNSGProps
                        $SubnetNSGObj | Export-Csv -Append -NoTypeInformation $ExportPath
                        
                        # Cleanup
                        Clear-Variable Rule
                        Clear-Variable SubnetNSGObj
                    }     
                # If only default rules exist, capture ruleset
                }elseif ($SubnetNSG.DefaultSecurityRules -and !$SubnetNSG.SecurityRules) {
                    # Default
                    foreach ($Rule in $SubnetNSG.DefaultSecurityRules)
                    {
                        $SubnetNSGProps = [ordered]@{
                            VMName          = $VM.Name
                            VMResourceGrp   = $VM.ResourceGroupName
                            VMState         = $VM.PowerState
                            Location        = $VM.location
                            LinkedNICName   = $LinkedNIC.Name
                            NICIPConfigName = $LinkedNICConfig.name
                            LinkedNICIP     = $LinkedNICConfig.privateipaddress 
                            PIPName         = $PIPName
                            PIPAddress      = $PIPAddress
                            SubnetName      = $VMSubnet.Name     
                            Subscription    = $Sub.Name
                            NSGAttached     = "Subnet"
                            NSGName         = $SubnetNSG.Name
                            RuleName        = $Rule.Name
                            Protocol        = $Rule.Protocol
                            Direction       = $Rule.Direction
                            Source          = $Rule.SourceAddressPrefix -join ";"
                            SourcePortRange = $Rule.SourcePortRange -join ";"
                            Destination     = $Rule.DestinationAddressPrefix -join ";"
                            DestPortRange   = $Rule.DestinationPortRange -join ";"
                            Access          = $Rule.Access
                            Priority        = $Rule.Priority
                            LinkType        = "SubnetNSG (Default Rules)"
                        }

                        $SubnetNSGObj = New-Object -TypeName PSObject -Property $SubnetNSGProps
                        $SubnetNSGObj | Export-Csv -Append -NoTypeInformation $ExportPath
                        
                        # Cleanup
                        Clear-Variable Rule
                        Clear-Variable SubnetNSGObj
                    } 
                }else{
                    # If no default or subnet rules
                    $SubnetNSGProps = [ordered]@{
                        VMName          = $VM.Name
                        VMResourceGrp   = $VM.ResourceGroupName
                        VMState         = $VM.PowerState
                        Location        = $VM.location
                        LinkedNICName   = $LinkedNIC.Name
                        NICIPConfigName = $LinkedNICConfig.name
                        LinkedNICIP     = $LinkedNICConfig.privateipaddress 
                        PIPName         = $PIPName
                        PIPAddress      = $PIPAddress 
                        SubnetName      = $VMSubnet.Name      
                        Subscription    = $Sub.Name
                        NSGAttached     = "no nsg associated to subnet"
                        NSGName         = "n/a"
                        RuleName        = "n/a"
                        Protocol        = "n/a"
                        Direction       = "n/a"
                        Source          = "n/a"
                        SourcePortRange = "n/a"
                        Destination     = "n/a"
                        DestPortRange   = "n/a"
                        Access          = "n/a"
                        Priority        = "n/a"
                        LinkType        = "SubnetNSG (No Rules)"
                    }

                    $SubnetNSGObj = New-Object -TypeName PSObject -Property $SubnetNSGProps
                    $SubnetNSGObj | Export-Csv -Append -NoTypeInformation $ExportPath
                    
                    # Cleanup
                    Clear-Variable Rule
                    Clear-Variable SubnetNSGObj
                }
                
                # Get NSG object linked to network interface
                $NICNSG = $NSGs | Where-Object {$_.id -eq $LinkedNIC.NetworkSecurityGroup.id}
                
                if ($NICNSG.DefaultSecurityRules -and $NICNSG.SecurityRules)
                {
                    # Default
                    foreach ($Rule in $NICNSG.DefaultSecurityRules)
                    {
                        $NICNSGProps = [ordered]@{
                            VMName          = $VM.Name
                            VMResourceGrp   = $VM.ResourceGroupName
                            VMState         = $VM.PowerState
                            Location        = $VM.location
                            LinkedNICName   = $LinkedNIC.Name
                            NICIPConfigName = $LinkedNICConfig.name
                            LinkedNICIP     = $LinkedNICConfig.privateipaddress 
                            PIPName         = $PIPName
                            PIPAddress      = $PIPAddress
                            SubnetName      = $VMSubnet.Name          
                            Subscription    = $Sub.Name
                            NSGAttached     = "NIC"
                            NSGName         = $NICNSG.Name
                            RuleName        = $Rule.Name
                            Protocol        = $Rule.Protocol
                            Direction       = $Rule.Direction
                            Source          = $Rule.SourceAddressPrefix -join ";"
                            SourcePortRange = $Rule.SourcePortRange -join ";"
                            Destination     = $Rule.DestinationAddressPrefix -join ";"
                            DestPortRange   = $Rule.DestinationPortRange -join ";"
                            Access          = $Rule.Access
                            Priority        = $Rule.Priority
                            LinkType        = "NIC NSG (Default Rules)"
                        }

                        $NICNSGObj = New-Object -TypeName PSObject -Property $NICNSGProps
                        $NICNSGObj | Export-Csv -Append -NoTypeInformation $ExportPath
                        
                        # Cleanup
                        Clear-Variable Rule
                        Clear-Variable NICNSGObj
                    }

                    # Custom
                    foreach ($Rule in $NICNSG.SecurityRules)
                    {
                        $NICNSGProps = [ordered]@{
                            VMName          = $VM.Name
                            VMResourceGrp   = $VM.ResourceGroupName
                            VMState         = $VM.PowerState
                            Location        = $VM.location
                            LinkedNICName   = $LinkedNIC.Name
                            NICIPConfigName = $LinkedNICConfig.name
                            LinkedNICIP     = $LinkedNICConfig.privateipaddress
                            PIPName         = $PIPName
                            PIPAddress      = $PIPAddress
                            SubnetName      = $VMSubnet.Name          
                            Subscription    = $Sub.Name
                            NSGAttached     = "NIC"
                            NSGName         = $NICNSG.Name
                            RuleName        = $Rule.Name
                            Protocol        = $Rule.Protocol
                            Direction       = $Rule.Direction
                            Source          = $Rule.SourceAddressPrefix -join ";"
                            SourcePortRange = $Rule.SourcePortRange -join ";"
                            Destination     = $Rule.DestinationAddressPrefix -join ";"
                            DestPortRange   = $Rule.DestinationPortRange -join ";"
                            Access          = $Rule.Access
                            Priority        = $Rule.Priority
                            LinkType        = "NIC NSG (Custom Rules)"
                        }

                        $NICNSGObj = New-Object -TypeName PSObject -Property $NICNSGProps
                        $NICNSGObj | Export-Csv -Append -NoTypeInformation $ExportPath
                        
                        # Cleanup
                        Clear-Variable Rule
                        Clear-Variable NICNSGObj
                    }
                }elseif ($NICNSG.DefaultSecurityRules -and !$NICNSG.SecurityRules) {
                    foreach ($Rule in $NICNSG.DefaultSecurityRules)
                    {
                        $NICNSGProps = [ordered]@{
                            VMName          = $VM.Name
                            VMResourceGrp   = $VM.ResourceGroupName
                            VMState         = $VM.PowerState
                            Location        = $VM.location
                            LinkedNICName   = $LinkedNIC.Name
                            NICIPConfigName = $LinkedNICConfig.name
                            LinkedNICIP     = $LinkedNICConfig.privateipaddress 
                            PIPName         = $PIPName
                            PIPAddress      = $PIPAddress
                            SubnetName      = $VMSubnet.Name          
                            Subscription    = $Sub.Name
                            NSGAttached     = "NIC"
                            NSGName         = $NICNSG.Name
                            RuleName        = $Rule.Name
                            Protocol        = $Rule.Protocol
                            Direction       = $Rule.Direction
                            Source          = $Rule.SourceAddressPrefix -join ";"
                            SourcePortRange = $Rule.SourcePortRange -join ";"
                            Destination     = $Rule.DestinationAddressPrefix -join ";"
                            DestPortRange   = $Rule.DestinationPortRange -join ";"
                            Access          = $Rule.Access
                            Priority        = $Rule.Priority
                            LinkType        = "NIC NSG (Custom Rules)"
                        }

                        $NICNSGObj = New-Object -TypeName PSObject -Property $NICNSGProps
                        $NICNSGObj | Export-Csv -Append -NoTypeInformation $ExportPath
                        
                        # Cleanup
                        Clear-Variable Rule
                        Clear-Variable NICNSGObj
                    }
                }else {
                    # For VMs with nics that don't have an associated NSG
                    $NICNSGProps = [ordered]@{
                        VMName          = $VM.Name
                        VMResourceGrp   = $VM.ResourceGroupName
                        VMState         = $VM.PowerState
                        Location        = $VM.location
                        LinkedNICName   = $LinkedNIC.Name
                        NICIPConfigName = $LinkedNICConfig.name
                        LinkedNICIP     = $LinkedNICConfig.privateipaddress
                        PIPName         = $PIPName
                        PIPAddress      = $PIPAddress
                        SubnetName      = $VMSubnet.Name       
                        Subscription    = $Sub.Name
                        NSGAttached     = "no nsg associated to nic"
                        NSGName         = "n/a"
                        RuleName        = "n/a"
                        Description     = "n/a"
                        Protocol        = "n/a"
                        Direction       = "n/a"
                        Source          = "n/a"
                        SourcePortRange = "n/a"
                        Destination     = "n/a"
                        DestPortRange   = "n/a"
                        Access          = "n/a"
                        Priority        = "n/a"
                        LinkType        = "NIC NSG (No Rules)"
                    }

                    $NICNSGObj = New-Object -TypeName PSObject -Property $NICNSGProps 
                    $NICNSGObj | Export-Csv -Append -NoTypeInformation $ExportPath
                    
                    # Cleanup
                    Clear-Variable Rule
                    Clear-Variable NICNSGObj
                }
            }
        } 

    } # foreach ($VM in $VMs)
}