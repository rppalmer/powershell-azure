# Gets detail for Azure App Services + Front Door coverage
$TenantId           = "xxx"
$ActiveSubscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object {$_.State -eq "Enabled" -and $_.name -notmatch "Visual Studio" -and $_.name -notmatch "citrix"}  
#$ActiveSubscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object {$_.State -eq "Enabled" -and $_.name -notmatch "Visual Studio" -and $_.name -notmatch "citrix" -and $_.SubscriptionId -eq "67e6c130-213c-4abf-bc98-db9a0825428e"}  # TESTING


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

Foreach ($Sub in $ActiveSubscriptions)
{

    Set-AzContext -SubscriptionId $Sub.Id -TenantId $TenantId | Out-Null
    
    # Get list of providers
    try
    {
        $Providers = Get-AzResourceProvider -ListAvailable
    }catch{
        "subscription in a state that prevents provider listing"
    }

    # APP SERVICES
    $ProviderName = "Microsoft.Web"
    $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
    
    if ($providerCheck -eq $true)
    {
        # For each running/enabled App Service...
        #$Webapps = Get-AzWebApp -Name Corporate-website-Prod -ResourceGroupName hpfc-website
        $Webapps = Get-AzWebApp | Select-Object Name, ResourceGroup
        
        Foreach ($WebApp in $Webapps)
        {
            $Webapp = Get-AzWebApp -Name $Webapp.Name -ResourceGroupName $Webapp.ResourceGroup
            
            # find IP restrictions
            foreach ($Entry in $Webapp.SiteConfig.IpSecurityRestrictions.Name)
            {
                if ($Entry -eq "Deny all")
                {
                    $IPFilter = $True
                    Break
                }else{
                    $IPFilter = $False
                }
            }

            foreach ($Hostname in $WebApp.EnabledHostNames)
            {
                # create object for reporting
                $WebAppProps = [ordered]@{
                    Name             = $WebApp.Name
                    RGName           = $WebApp.ResourceGroup
                    Location         = $WebApp.Location
                    Type             = $Webapp.Type
                    Kind             = $WebApp.Kind
                    FTPState         = $Webapp.SiteConfig.FtpsState
                    HTTPSOnly        = $Webapp.HttpsOnly
                    EnabledHostNames = $Hostname
                    IPRestrictions   = $IPFilter
                    State            = $WebApp.State
                    Enabled          = $WebApp.Enabled
                    IPAddress        = (Resolve-DnsName $WebApp.DefaultHostName).IP4Address
                    Subscription     = $Sub.Name
                }

                $WebAppObj = New-Object -TypeName PSObject -Property $WebAppProps
                $WebAppObj | Export-Csv -NoTypeInformation -Append c:\tmp\appservice_details.csv
            }
                
            # Get Web Slots if present
            try {
                $WebAppSlots = Get-AzWebAppSlot -ResourceGroupName $WebApp.ResourceGroup -Name $WebApp.Name -ErrorAction Stop
            }catch{
                Write-Host "$($WebApp.name) does not have any slots, skipping..."
            }

            # if webappslots present, loop through each hostname and determine if there is frontdoor coverage
            if ($WebAppSlots)
            {
                foreach ($WebAppSlot in $WebAppSlots)
                { 
                    # find IP restrictions
                    foreach ($Entry in $WebappSlot.SiteConfig.IpSecurityRestrictions.Name)
                    {
                        if ($Entry -eq "Deny all")
                        {
                            $IPFilter = $True
                            Break
                        }else{
                            $IPFilter = $False
                        }
                    }

                    foreach ($AppSlotHostname in $WebAppSlot.EnabledHostNames)
                    {
                        # create object for reporting
                        $WebAppSlotProps = [ordered]@{
                            Name             = $WebAppSlot.Name
                            RGName           = $WebAppSlot.ResourceGroup
                            Location         = $WebAppSlot.Location
                            Type             = $WebAppSlot.Type
                            Kind             = "app-slot"
                            FTPState         = $Webapp.SiteConfig.FtpsState
                            HTTPSOnly        = $Webapp.HttpsOnly
                            EnabledHostNames = $AppSlotHostname
                            IPRestrictions   = $IPFilter
                            State            = $WebAppSlot.State
                            Enabled          = $WebAppSlot.Enabled
                            IPAddress        = (Resolve-DnsName $WebApp.DefaultHostName).IP4Address
                            Subscription     = $Sub.Name
                        }

                        $WebAppSlotObj = New-Object -TypeName PSObject -Property $WebAppSlotProps
                        $WebAppSlotObj | Export-Csv -NoTypeInformation -Append c:\tmp\appservice_details.csv
                    }
                }
            }
            
            Clear-Variable WebAppSlots
            if($IPFilter){Clear-Variable IPFilter}

        }
    }
}   