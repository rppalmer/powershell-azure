Foreach ($Sub in (Get-AzSubscription | Where-Object {$_.state -eq "Enabled"}))
{
    Set-AzContext -Subscription $Sub.Id -Tenant "xxx"

    foreach ($NSG in (Get-AzNetworkSecurityGroup | Select-Object Name, SecurityRules, ResourceGroupName, Location))
    {
        foreach ($NSGRule in $NSG.SecurityRules | Where-Object {$_.DestinationPortRange -eq "3389"})
        {
            ## NSG Object
            $NSGProps = [ordered]@{
                Name            = $NSG.Name
                RGName          = $NSG.ResourceGroupName
                Location        = $NSG.Location
                NSGRuleName     = $NSGRule.Name
                Description     = $NSGRule.Description
                Access          = $NSGRule.Access
                Direction       = $NSGRule.Direction
                DstPortRange    = $NSGRule.DestinationPortRange -join ";"
                Protocol        = $NSGRule.Protocol
                SrcAddrPrefix   = $NSGRule.SourceAddressPrefix -join ";"
                DstAddrPrefix   = $NSGRule.DestinationAddressPrefix -join ";"
                Priority        = $NSGRule.Priority
                Subscription    = $Sub.Name
            }
        
            $NSGObj = New-Object -TypeName PSObject -Property $NSGProps
            $NSGObj | Export-Csv -NoTypeInformation -Append "c:\tmp\20220504_RDPNSGExport.csv"
            
        }
    }
}