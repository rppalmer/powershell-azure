# Gets detail for Azure App Services + Front Door coverage

$ActiveSubscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object {$_.State -eq "Enabled" -and $_.name -notmatch "Visual Studio" -and $_.name -notmatch "citrix"}  
#$ActiveSubscriptions = Get-AzSubscription -TenantId $TenantId | Where-Object {$_.State -eq "Enabled" -and $_.name -notmatch "Visual Studio" -and $_.name -notmatch "citrix" -and $_.SubscriptionId -eq "67e6c130-213c-4abf-bc98-db9a0825428e"}  # TESTING
$TenantId           = "483fadee-89c9-4311-912d-37212c6f09aa"
$hostnames_arr  = @("hpfc-closingapps-dev.azurewebsites.net","fraudinvestigationmanagerview.azurewebsites.net","hpftpo-ux-prod.azurewebsites.net","hpfcapippe1.eastus.cloudapp.azure.com","hpftpo-ux-prod.azurewebsites.net","cellphoneoptinoptoutwebapi-uat.azurewebsites.net","cellphoneoptinoptoutview.azurewebsites.net","cellphoneoptinoptoutwebapi-dev.azurewebsites.net","cellphoneoptinoptoutwebapi.azurewebsites.net","cellphoneoptinoptoutwebapi-qa.azurewebsites.net","cellphoneoptinoptoutview-dev.azurewebsites.net","cellphoneoptinoptoutview-qa.azurewebsites.net","cellphoneoptinoptoutview-uat.azurewebsites.net","fraudinvestigationmanagerapi.azurewebsites.net","fraudinvestigationmanagerapi-uat.azurewebsites.net","fraudinvestigationmanagerapi-qa.azurewebsites.net","fraudinvestigationmanagerapi-dev.azurewebsites.net","fraudinvestigationmanagerview.azurewebsites.net","fraudinvestigationmanagerview.azurewebsites.net","fraudinvestigationmanagerview.azurewebsites.net","fraudinvestigationmanagerview.azurewebsites.net","52.147.217.172","ccparequests.azurewebsites.net","hpfc-website.azurewebsites.net","hpfc-website.azurewebsites.net","hpmac-client-portal.azurewebsites.net","hpmac-client-portal-w.azurewebsites.net","hpfc-utilities-ui-dev-qa.azurewebsites.net","hpfc-utilities-api-dev-qa.azurewebsites.net","hpfc-utilities-ui-dev-qa.azurewebsites.net","hpfc-utilities-api-dev.azurewebsites.net","hpfc-utilities-ui-dev.azurewebsites.net","hpfc-utilities-api-prod.azurewebsites.net","hpfc-utilities-ui-prod.azurewebsites.net","52.147.217.172","13.92.47.121","52.147.217.172","13.92.47.121","hopsaml2pidp.azurewebsites.net","identityserverdevelopment-sso.azurewebsites.net","identityserverdevelopment.azurewebsites.net","identityserver-prod.azurewebsites.net","login-homepoint.azurewebsites.net","hpfc-closingapps.azurewebsites.net","devesvcmacloanapi.azurewebsites.net","qaesvcmacloanapi.azurewebsites.net","rcesvcmacloanapi.azurewebsites.net","devesvcmacauditapi.azurewebsites.net","qaesvcmacauditapi.azurewebsites.net","rcesvcmacauditapi.azurewebsites.net","devesvcmacapifunc.azurewebsites.net","qaesvcmacapifunc.azurewebsites.net","rcesvcmacapifunc.azurewebsites.net","deveapexsearchfa.azurewebsites.net","orange-grass-0dc1f060f.1.azurestaticapps.net","deveapexwebbfffa.azurewebsites.net","kind-flower-0f45b390f.1.azurestaticapps.net","qaeapexwebbfffa.azurewebsites.net","qaeapexsearchfa.azurewebsites.net","orange-grass-0dc1f060f-dev1.eastus2.1.azurestaticapps.net","ambitious-dune-0dda5eb0f.1.azurestaticapps.net","rceapexwebbfffa.azurewebsites.net","rceapexsearchfa.azurewebsites.net","orange-grass-0dc1f060f-dev2.eastus2.1.azurestaticapps.net","orange-grass-0dc1f060f-dev3.eastus2.1.azurestaticapps.net","orange-grass-0dc1f060f-dev4.eastus2.1.azurestaticapps.net","orange-grass-0dc1f060f-dev5.eastus2.1.azurestaticapps.net","qaeapexuserfa.azurewebsites.net","rceapexuserfa.azurewebsites.net","deveapexuserfa.azurewebsites.net","rceapi.homepointfinancial.net","rcwapi.homepointfinancial.net","homepoint.azure-api.net","rcetpoapim.azure-api.net","rcwtpoapim.azure-api.net","rcetpoapim.azure-api.net","rcwtpoapim.azure-api.net","hpxkubernetes-dev.hpfc.dev","hpxkubernetes-qa.hpfc.dev","hpxkubernetes-rc.hpfc.dev","prdedcproxyapim.azure-api.net","prdecorpwebsiteas.azurewebsites.net","prdwcorpwebsiteas.azurewebsites.net","devecorpwebsiteas.azurewebsites.net","devwcorpwebsiteas.azurewebsites.net","prdecorpwebsiteas.azurewebsites.net","prdwcorpwebsiteas.azurewebsites.net","devecorpwebsiteas.azurewebsites.net","devwcorpwebsiteas.azurewebsites.net","hpfc-website.azurewebsites.net","hpfc-website.azurewebsites.net","devedcproxyapim.azure-api.net","qaedcproxyapim.azure-api.net","rcedcproxyapim.azure-api.net","prdeapi.homepointfinancial.net","prdwapi.homepointfinancial.net","homepoint.azure-api.net","prdwtpoapim.azure-api.net","prdetpoapim.azure-api.net","prdwtpoapim.azure-api.net","prdetpoapim.azure-api.net","deveopsgenfunfunc.azurewebsites.net","qaeopsgenfunfunc.azurewebsites.net","devewholeldas-demo.azurewebsites.net","prdeopsgenfunfunc.azurewebsites.net","prdesvcmacloanapi.azurewebsites.net","prdesvcmacauditapi.azurewebsites.net","prdesvcmacapifunc.azurewebsites.net","hpxkubernetes-prod.hpfc.dev","deveppeobclientapp.azurewebsites.net","rceppeobclientapp.azurewebsites.net","qaeppeobclientapp.azurewebsites.net","deveppeobclientapp-deveppeobclientappslot.azurewebsites.net","qaeppeobclientapp-qaeppeobclientappslot.azurewebsites.net","rceppeobclientapp-rceppeobclientappslot.azurewebsites.net","deveppeobapiapp.azurewebsites.net","qaeppeobapiapp.azurewebsites.net","deveppeobapiapp-deveppeobapiappslot.azurewebsites.net","rceppeobapiapp.azurewebsites.net","qaeppeobapiapp-qaeppeobapiappslot.azurewebsites.net","rceppeobapiapp-rceppeobapiappslot.azurewebsites.net","hpxkubernetes-rc.hpfc.dev","prdeppeobclientapp.azurewebsites.net","prdeppeobclientapp-prdeppeobclientappslot.azurewebsites.net","prdeppeobapiapp.azurewebsites.net","prdeppeobapiapp-prdeppeobapiappslot.azurewebsites.net","hpmac-portal.azurewebsites.net","devclosingappsfd.azurefd.net","closing-dev.homepointfinancial.net","prdfraudinvestigationmanagerfd.azurefd.net","fraudinvestigationmanager.hpfc.app","prdhpftpouxfd.azurefd.net","portal.hpfctpo.com","apippe.homepointfinancial.net","hpfc-apippe.azurefd.net","portal-azure.hpfctpo.com","homepoint.azurefd.net","cell-optapi-uat.homepointfinancial.com","cell-optapi-qa.homepointfinancial.com","cell-optapi-dev.homepointfinancial.com","cell-opt.homepointfinancial.com","cellphoneoptinoptoutfd.azurefd.net","cell-opt-uat.homepointfinancial.com","cell-opt-dev.homepointfinancial.com","cell-optapi.homepointfinancial.com","cell-opt-qa.homepointfinancial.com","homepointfinancial-com.azurefd.net","fraud-invmanagerAPI.homepointfinancial.com","fraud-invmanagerAPI-qa.homepointfinancial.com","fraud-invmanagerAPI-uat.homepointfinancial.com","fraud-invmanagerAPI-dev.homepointfinancial.com","fraud-invmanager.homepointfinancial.com","fraud-invmanager-qa.homepointfinancial.com","fraud-invmanager-uat.homepointfinancial.com","fraud-invmanager-dev.homepointfinancial.com","hpfc-dev-fd.azurefd.net","ccparequestsfd.azurefd.net","my-info.homepointfinancial.com","webresourcesfd.azurefd.net","resources.homepoint.com","tpo.homepoint.com","tpo.homepointfinancial.com","resources.homepointfinancial.com","dallas.homepointfinancial.com","wholesale.homepointfinancial.com","tpo-content.homepointfinancial.com","hpmacclientportal.azurefd.net","portal.hpmac.com","tpoutility.azurefd.net","tpoutility-api-qa.homepointfinancial.com","tpoutility-qa.homepointfinancial.com","tpoutility-api-dev.homepointfinancial.com","tpoutility-dev.homepointfinancial.com","tpoutility-api.homepointfinancial.com","tpoutility.homepointfinancial.com","tpoutility-apisdk-dev.homepointfinancial.com","tpoutility-apisdk-qa.homepointfinancial.com","tpoutility-apisdk-rc.homepointfinancial.com","tpoutility-apisdk.homepointfinancial.com","identmyhpfc.azurefd.net","login.mydev.hpfc.com","login.my.hpfc.com","prdclosingappsfd.azurefd.net","closing.homepointfinancial.net","npdsvcmacapifd.azurefd.net","devsvcmacloanapi.hpfc.dev","qasvcmacloanapi.hpfc.dev","devsvcmacauditapi.hpfc.dev","qasvcmacauditapi.hpfc.dev","rcsvcmacloanapi.hpfc.dev","rcsvcmacauditapi.hpfc.dev","qasvcmacapifunc.hpfc.dev","devsvcmacapifunc.hpfc.dev","rcsvcmacapifunc.hpfc.dev","npdapexfd.azurefd.net","devapexweb.hpfc.dev","devapexwebbff.hpfc.dev","devapexsearch.hpfc.dev","qaapexweb.hpfc.dev","qaapexwebbff.hpfc.dev","qaapexsearch.hpfc.dev","devapexweb1.hpfc.dev","rcapexweb.hpfc.dev","rcapexwebbff.hpfc.dev","rcapexsearch.hpfc.dev","devapexweb2.hpfc.dev","devapexweb3.hpfc.dev","devapexweb4.hpfc.dev","devapexweb5.hpfc.dev","qaapexuser.hpfc.dev","rcapexuser.hpfc.dev","devapexuser.hpfc.dev","rcapi.azurefd.net","rcapi.homepointfinancial.net","apirc.homepointfinancial.net","npdhpxfd.azurefd.net","devhpx.hpfc.dev","qahpx.hpfc.dev","rchpx.hpfc.dev","prddcproxyfd.azurefd.net","prddcproxy.hpfc.com","hpcorpwebsite.azurefd.net","dev.www.homepoint.net","uat.www.homepoint.net","prd.www.homepoint.net","qa.www.homepoint.net","homepoint.com","www.homepoint.com","www.homepointfinancial.com","homepointfinancial.com","apply.homepointfinancial.com","payoff-request.homepointfinancial.com","lnl.homepointfinancial.com","npddcproxyfd.azurefd.net","devdcproxy.hpfc.dev","qadcproxy.hpfc.dev","rcdcproxy.hpfc.dev","prdapifd.azurefd.net","api.homepointfinancial.net","prdapi.homepointfinancial.net","devopsgenfunfee.hpfc.dev","opsgenfunfd.azurefd.net","qaopsgenfunfee.hpfc.dev","devwld.hpfc.app","devwld.azurefd.net","prdopsgenfunfd.azurefd.net","prdsvcmacapifd.azurefd.net","prdsvcmacauditapi.hpfc.app","prdsvcmacloanapi.hpfc.app","prdsvcmacapifunc.hpfc.app","hpx.hpfc.dev","prdhpxfd.azurefd.net","npdppeobfd.azurefd.net","devppeobclientapp.hpfc.dev","rcppeobclientapp.hpfc.dev","qappeobclientapp.hpfc.dev","devppeobclientappslot.hpfc.dev","qappeobclientappslot.hpfc.dev","rcppeobclientappslot.hpfc.dev","devppeobapiapp.hpfc.dev","rcppeobapiapp.hpfc.dev","qappeobapiapp.hpfc.dev","devppeobapiappslot.hpfc.dev","qappeobapiappslot.hpfc.dev","rcppeobapiappslot.hpfc.dev","hpxkubernetesrcfd.azurefd.net","prdppeobfd.azurefd.net","prdppeobclientapp.hpfc.com","prdppeobclientappslot.hpfc.com","prdppeobapiapp.hpfc.com","prdppeobapiappslot.hpfc.com","client-portal.azurefd.net","client.hpmac.com")

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


            # For each app service url, if any match frontdoor hostnames, set $FrontDoorDetection to true
            foreach ($Hostname in $WebApp.EnabledHostNames)
            {
                if ($Hostname -in $Hostnames_arr){
                    $FrontDoorDetection = $True
                }else{
                    $FrontDoorDetection = $False
                }

                # create object for reporting
                $WebAppProps = [ordered]@{
                    Name             = $WebApp.Name
                    RGName           = $WebApp.ResourceGroup
                    Location         = $WebApp.Location
                    Type             = $Webapp.Type
                    Kind             = $WebApp.Kind
                    FTPState         = $Webapp.SiteConfig.FtpsState
                    EnabledHostNames = $Hostname
                    IPRestrictions   = $IPFilter
                    State            = $WebApp.State
                    Enabled          = $WebApp.Enabled
                    IPAddress        = (Resolve-DnsName $WebApp.DefaultHostName).IP4Address
                    Subscription     = $Sub.Name
                    FDEnabled        = $FrontDoorDetection
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
                        if ($AppSlotHostname -in $Hostnames_arr){
                            $FrontDoorDetection = $True
                        }else{
                            $FrontDoorDetection = $False
                        }

                        # create object for reporting
                        $WebAppSlotProps = [ordered]@{
                            Name             = $WebAppSlot.Name
                            RGName           = $WebAppSlot.ResourceGroup
                            Location         = $WebAppSlot.Location
                            Type             = $WebAppSlot.Type
                            Kind             = "app-slot"
                            FTPState         = $Webapp.SiteConfig.FtpsState
                            EnabledHostNames = $AppSlotHostname
                            IPRestrictions   = $IPFilter
                            State            = $WebAppSlot.State
                            Enabled          = $WebAppSlot.Enabled
                            IPAddress        = (Resolve-DnsName $WebApp.DefaultHostName).IP4Address
                            Subscription     = $Sub.Name
                            FDEnabled        = $FrontDoorDetection
                        }

                        $WebAppSlotObj = New-Object -TypeName PSObject -Property $WebAppSlotProps
                        $WebAppSlotObj | Export-Csv -NoTypeInformation -Append c:\tmp\appservice_details.csv
                    }
                }
            }
            
            Clear-Variable FrontDoorDetection
            Clear-Variable WebAppSlots
            if($IPFilter){Clear-Variable IPFilter}

        }
    }
}   