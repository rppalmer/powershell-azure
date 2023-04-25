<# 
.SYNOPSIS 
    Exports SQL Firewall rules SQL Servers
.DESCRIPTION 
    Exports SQL Firewall rules SQL Servers
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  5/5/2021
    Purpose/Change: Initial script development

#> 

$timestamp = Get-Date -UFormat "%Y%m%d"
$ExportPath = "C:\tmp\"+$timestamp+"externalAssetSec_"

Foreach ($Sub in (Get-AzSubscription | Where-Object {$_.state -eq "Enabled"} ))
{
    Set-AzContext -Subscription $Sub.Id -Tenant "xxx"
    
    # Loop through all the SQL Servers
    foreach ($SQLServer in (Get-AzSQLServer))
    {
        # Get firewall rules
        $Rules = Get-AzSqlServerFirewallRule -Servername $SQLServer.Servername -ResourceGroupName $SQLServer.ResourceGroupName
        
        # if firewall rules exist...
        if ($Rules)
        {
            # Record each rule along with server info
            foreach ($Rule in $Rules)
            {
                $RuleProps = [ordered]@{
                    ServerName      = $SQLServer.ServerName
                    RGName          = $SQLServer.ResourceGroupName
                    Location        = $SQLServer.Location
                    Subscription    = $Sub.Name
                    SQLAdminLogin   = $SQLServer.SQLAdministratorLogin
                    PublicNetAccess = $SQLServer.PublicNetworkAccess
                    FwRuleName      = $Rule.FirewallRuleName
                    StartIPAddr     = $Rule.StartIpAddress
                    EndIpAddr       = $Rule.EndIPAddress
                }

                $SQLServerObj = New-Object -TypeName PSObject -Property $RuleProps
                $SQLServerObj | export-csv -append -NoTypeInformation $ExportPath"SQLServerFWRules.csv"
                
            }
            
            # If no rules exist, fill with n/a to indicate
            $RuleProps = [ordered]@{
                ServerName      = $SQLServer.ServerName
                RGName          = $SQLServer.ResourceGroupName
                Location        = $SQLServer.Location
                Subscription    = $Sub.Name
                SQLAdminLogin   = $SQLServer.SQLAdministratorLogin
                PublicNetAccess = $SQLServer.PublicNetworkAccess
                FwRuleName      = "n/a"
                StartIPAddr     = "n/a"
                EndIpAddr       = "n/a"
            }

            $SQLServerObj = New-Object -TypeName PSObject -Property $RuleProps
            $SQLServerObj | export-csv -append -NoTypeInformation $ExportPath"SQLServerFWRules.csv"
        }
    }
}