<# 
.SYNOPSIS 
    Deletes auto-created Azure SQL Firewall rules
.DESCRIPTION 
    Deletes auto-created Azure SQL Firewall rules
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  1/26/2023
    Purpose/Change: Initial script development

#> 

Foreach ($Sub in (Get-AzSubscription | Where-Object {$_.state -eq "Enabled"} ))
{
    
    Set-AzContext -Subscription $Sub.Id -Tenant "xxx" | Out-Null
    
    # Loop through all the SQL Servers
    foreach ($SQLServer in (Get-AzSQLServer))
    {
        # Get firewall rules
        $Rules = Get-AzSqlServerFirewallRule -Servername $SQLServer.Servername -ResourceGroupName $SQLServer.ResourceGroupName
        
        # if firewall rules exist...
        if ($Rules)
        {
            # Record each rule along with server info
            foreach ($Rule in $Rules | Where-Object {$_.FirewallRuleName -match "ClientIPAddress_"})
            {
                Write-Host "Dry Run: Would Delete >> $($SQLServer.ServerName) $($SQLServer.ResourceGroupName) $($Rule.FirewallRuleName)"
                
                #Remove-AzSqlServerFirewallRule -ServerName $SQLServer.ServerName -ResourceGroupName $SQLServer.ResourceGroupName -FirewallRuleName $Rule.FirewallRuleName
            }
        }
    }
}