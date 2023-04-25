<# 
.SYNOPSIS 
    Exports LB data for all subscriptions
.DESCRIPTION 
    Exports LB data for all subscriptions
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  4/28/2021
    Purpose/Change: Initial script development

#> 


        # Cleanup
        if ($LBObj){Clear-Variable LBObj}
        if ($BackendPool){Clear-Variable BackendPool}
        If ($PIPName){Clear-Variable PIPName}
        If ($LinkedPIP){Clear-Variable LinkedPIP}

# Path to CSV
$timestamp = Get-Date -UFormat "%Y%m%d"
$ExportPath = "C:\tmp\"+$timestamp+"_LBConfigReview.csv"

Foreach ($Sub in (Get-AzSubscription | Where-Object {$_.state -eq "Enabled"}))
{
    
    Select-AzSubscription -Subscriptionid $Sub.id | out-null

    # Get info on associated resources
    $LBs = Get-AzLoadBalancer
    $PIPs = Get-AzPublicIpAddress
    $NICs = Get-AzNetworkInterface

    # Loop through load balancers
    foreach ($LB in $LBs )
    {
        
        # backend address pools
        if ($LB.BackEndAddressPools)
        {
            $BackendPool = $True
        }else {
            $BackendPool = $False
        }
        
        # get PIP information, or set as n/a if not configured
        if (($LB.frontendipconfigurations.publicipaddress).count -gt 1)
        {
            # some LBs have multiple PIPs
            foreach ($PIP in $lb.frontendipconfigurations.publicipaddress)
            {
                $PIPName += ($PIPs | Where-Object {$_.id -eq $PIP.id}).Name+"`n"
                $LinkedPIP += ($PIPs | Where-Object {$_.id -eq $PIP.id}).IpAddress+"`n"
            }
        }elseif(($LB.frontendipconfigurations.publicipaddress).count -eq 1)
        {
            $PIPName = ($PIPs | Where-Object {$_.id -eq $LB.frontendipconfigurations.publicipaddress.id}).Name
            $LinkedPIP = ($PIPs | Where-Object {$_.id -eq $LB.frontendipconfigurations.publicipaddress.id}).IpAddress
        }else {
            $PIPName = "No PIP Assigned"
            $LinkedPIP = "n/a"
        }
        
        # Array to store load balancing rules if they exist
        $LBRArr = @()
        # If load balancing rules exist...
        if ($LB.LoadBalancingRules)
        {
            foreach ($LBR in $LB.loadbalancingrules)
            {
                $LBRArr += "LBRName: " + $lbr.name + " FrontEndPort:" + $lbr.frontendport + " BackEndPort " + $lbr.backendport
            }
        }else{
            $LBRArr = "n/a"
        }
        
        # if inbount nat rules exist..
        if($LB.InboundNatRules)
        {   

            # loop through inbound nat rules
            foreach ($INR in $LB.InboundNatRules)
            {   
                
                # one to one relationship with Inbound NAT Rules and backend resources
                $BackEndResource = (($NICS | Where-Object {$_.ipconfigurations.id -eq $INR.BackendIpConfiguration.Id}).VirtualMachine.Id -split "/")[-1]

                if (!$INR.BackendIpConfiguration.Id)
                {
                    $BackEndResource = "n/a"
                }
                
                #if (!$BackEndResource)
                #{
                #    $BackEndResource = "n/a"
                #}

                $InboundNatRulesInf= ($NICS | Where-Object {$_.ipconfigurations.id -eq $INR.BackendIpConfiguration.Id}).name
                if (!$InboundNatRulesInf)
                {
                    $InboundNatRulesInf = "n/a"
                }
                
                $LBProps = [ordered]@{   
                    LBName = $LB.Name
                    RGName = $LB.ResourceGroupName
                    BackEndResource = $BackEndResource
                    Subscription = $Sub.Name
                    PIPName = $PIPName
                    LinkedPIP = $LinkedPIP
                    InboundNatRulesName = $INR.Name
                    InboundNatRulesInf = $InboundNatRulesInf
                    InboundNatRulesProt = $INR.Protocol
                    InboundNatRulesFEPort = $INR.FrontEndPort
                    InboundNatRulesBEPort = $INR.BackEndPort
                    BackEndPool = $BackEndPool
                    LoadBalancingRules = $LBRArr -join "`n"
                }

                $LBObj = New-Object -TypeName PSObject -Property $LBProps
                $LBObj | export-csv -append -NoTypeInformation $ExportPath
            }
        }elseif(!$LB.InboundNatRules)
        {
            $LBProps = [ordered]@{
                    
                LBName = $LB.Name
                RGName = $LB.ResourceGroupName
                BackEndResource = $BackEndResource
                Subscription = $Sub.Name
                PIPName = $PIPName
                LinkedPIP = $LinkedPIP
                InboundNatRulesName = "n/a"
                InboundNatRulesInf = "n/a"
                InboundNatRulesProt = "n/a"
                InboundNatRulesFEPort = "n/a"
                InboundNatRulesBEPort = "n/a"
                BackEndPool = $BackEndPool
                LoadBalancingRules = $LBRArr -join "`n"
                
            }

            $LBObj = New-Object -TypeName PSObject -Property $LBProps
            $LBObj | export-csv -append -NoTypeInformation $ExportPath

            Clear-Variable BackEndResource
            Clear-Variable PIPName
            Clear-Variable LinkedPIP
        }
    }
}


