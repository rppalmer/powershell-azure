# This version is not checking sql firewall rules, if private endpoint is in use, etc.

$ExportPath="C:\tmp\externalAssetSec_"

# Arrays for storing data
$IaaSArr=@();$WebAppsArr=@();$SQLServerArr=@();$StorageArr=@();$KVArr=@();$APIMgmtArr=@();$CGArr=@();$CRArr=@();$FDArr=@();$AKSArr=@()
$tenantId = "xx"
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
 
Foreach ($Sub in (Get-AzSubscription))
{
    # Select subscription and get all resources
    Set-AzContext -Subscription $Sub.Id -Tenant $tenantId

    # Get list of providers
    try
    {
        $Providers = Get-AzResourceProvider -ListAvailable
    }catch{
        "subscription in a state that prevents provider listing"
    }
    
    $AllResources = Get-Azresource 
    
    # If providerlist for sub isn't null
    if ($null -ne $Providers)
    {
        $ProviderName = "Microsoft.Network"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            $ActivePIPs = Get-AzPublicIpAddress | Where-Object {$_.IpAddress -notmatch "Not Assigned" -and $_.IpConfigurationText -ne "null"} 

            # IaaS
            Foreach ($PIP in $ActivePIPs)
            {
                $Resource = $AllResources | Where-Object {$_.id -eq $PIP.id }
            
                $IaaSProps = [ordered]@{
                    PIPName        = $PIP.Name
                    IPAddress      = $PIP.IpAddress
                    Location       = $PIP.Location
                    AssocResource  = $Resource.Name
                    AssocResGroup  = ($Resource.id -split "/")[4]
                    Type           = ($Resource.Type -split "/")[1]
                    Subscription   = $Sub.Name
                }
                $IaaSObj = New-Object -TypeName PSObject -Property $IaaSProps
                $IaaSArr += $IaaSObj
            } 
        } 

        ## APP SERVICES
        $ProviderName = "Microsoft.Web"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            Foreach ($WebApp in (Get-AzWebApp) | Where-Object {$_.state -eq "running" -and $_.enabled -eq "true" } | `
            Select-Object Name, DefaultHostName, ResourceGroup, Kind, EnabledHostNames, HttpsOnly, Tags)
            {
        
                $WebAppProps = [ordered]@{
                    Name            = $WebApp.Name
                    RGName          = $WebApp.ResourceGroup
                    Location        = $WebApp.Location
                    Type            = $Webapp.Type
                    Kind            = $WebApp.Kind
                    DefaultHostname = $WebApp.DefaultHostName
                    EnabledHostNames= $WebApp.EnabledHostNames -join ";"
                    IPAddress       = (Resolve-DnsName $WebApp.DefaultHostName).IP4Address
                    Subscription   =   $Sub.Name
                }
                $WebAppObj = New-Object -TypeName PSObject -Property $WebAppProps
                $WebAppsArr += $WebAppObj
            }
        }
        
        ## SQL Servers
        $ProviderName = "Microsoft.Sql"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            Foreach ($SQLServer in (Get-AzSQLServer | Select-Object ServerName, ResourceGroupName, Location, FullyQualifiedDomainName, ResourceId))
            {    
                $SQLServerProps = [ordered]@{
                    Name        = $SQLServer.ServerName
                    RGName      = $SQLServer.ResourceGroupName
                    Location    = $SQLServer.Location
                    Type        = ($SQLServer.ResourceId -split "/")[6]
                    FQDN        = $SQLServer.FullyQualifiedDomainName
                    IPAddress   = ((Resolve-DnsName $SQLServer.FullyQualifiedDomainName).IP4Address)
                    Subscription   =   $Sub.Name
                }
                $SQLServerObj = New-Object -TypeName PSObject -Property $SQLServerProps
                $SQLServerArr += $SQLServerObj
            }
        }

        ## STORAGE ACCOUNTS
        $ProviderName = "Microsoft.Storage"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            Foreach ($SA in (Get-AzStorageAccount | Select-Object * ))
            {
            
                $StorageProps = [ordered]@{
                    Name            = $SA.StorageAccountName
                    RGName          = $SA.ResourceGroupName
                    Location        = $SA.Location
                    Type            = ($SA.Id -split "/")[6]
                    BlobFQDN        = $SA.PrimaryEndpoints.Blob
                    FileFQDN        = $SA.PrimaryEndpoints.File
                    BlobIPAddress   = (Resolve-DnsName ($SA.primaryendpoints.blob -split "//" -replace "/","")[1]).ip4address
                    FileIPAddress   = (Resolve-DnsName ($SA.primaryendpoints.file -split "//" -replace "/","")[1]).ip4address
                    Subscription    = $Sub.Name
                }
                $StorageObj = New-Object -TypeName PSObject -Property $StorageProps
                $StorageArr += $StorageObj
                
            }

            
        }

        ## KEY VAULTS
        $ProviderName = "Microsoft.KeyVault"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            foreach ($KV in (Get-AzkeyVault | Select-Object VaultName, ResourceGroupName, ResourceId, Location, VaultURI))
            {
                $KVProps = [ordered]@{
                    Name         = $KV.VaultName
                    RGName       = $KV.ResourceGroupName
                    Location     = $KV.location
                    Type         = ($KV.ResourceId -split "/")[6]
                    #URL          = $KV.VaultURI
                    Subscription = $Sub.Name
                }
                $KVObj = New-Object -TypeName PSObject -Property $KVProps
                $KVArr += $KVObj
            }
        }

        ## API MANAGEMENT
        $ProviderName = "Microsoft.ApiManagement"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            Foreach ($APIMgmt in (Get-AzAPIManagement | Select-Object Name, ResourceGroupName, Id, RuntimeUrl, Location, PublisherEmail))
            {
                $APIMgmtProps = [ordered]@{
                    Name           = $APIMgmt.Name
                    RGName         = $APIMgmt.ResourceGroupName
                    Type           = ($APIMgmt.Id -split "/")[6]
                    RuntimeURL     = $APIMgmt.RuntimeURL
                    Location       = $APIMgmt.location
                    PublisherEmail = $APIMgmt.PublisherEmail
                    IPAddress      = (Resolve-DNSName ($APIMgmt.RuntimeURL -split "//" -replace "/","")[1]).ip4address
                    Subscription   = $Sub.Name
                }
                $APIMgmtObj = New-Object -TypeName PSObject -Property $APIMgmtProps
                $APIMgmtArr += $APIMgmtObj
            }
        }

        # CONTAINER GROUPS
        $ProviderName = "Microsoft.ContainerInstance"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            Foreach ($CG in (Get-AzContainerGroup | Select-Object Name, ResourceGroupName, id, Fqdn, Ports, Location, IpAddress))
            {
                $CGProps = [ordered]@{
                    Name           = $CG.Name
                    RGName         = $CG.ResourceGroupName
                    Type           = ($CG.Id -split "/")[6]
                    FQDN           = $CG.FQDN
                    Ports          = $CG.Ports -join ";"
                    Location       = $CG.location
                    IPAddress      = $CG.IPAddress
                    Subscription   = $Sub.Name
                }
                $CGObj = New-Object -TypeName PSObject -Property $CGProps
                $CGArr += $CGObj
            }
        }

        # CONTAINER REGISTRY
        $ProviderName = "Microsoft.ContainerRegistry"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            Foreach ($CR in (Get-AzContainerRegistry | Select-Object Name, ResourceGroupName, Type, LoginServer, CreationDate, Location))
            {
                $CRProps = [ordered]@{
                    Name           = $CR.Name
                    RGName         = $CR.ResourceGroupName
                    Type           = $CR.Type
                    LoginServer    = $CR.LoginServer
                    IPAddress      = (Resolve-DNSName $CR.LoginServer).ip4address
                    CreationDate   = $CR.CreationDate
                    Location       = $CR.location
                    Subscription   = $Sub.Name
                }
                $CRObj = New-Object -TypeName PSObject -Property $CRProps
                $CRArr += $CRObj
            }
        }

        # KUBERNETES
        $ProviderName = "Microsoft.ContainerService"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            Foreach ($AKS in (Get-AzAksCluster))
            {
                $AKSProps = [ordered]@{
                    Name              = $AKS.Name
                    RGName            = $AKS.NodeResourceGroup
                    Type              = $AKS.Type
                    Fqdn              = $AKS.FQDN
                    IPAddress         = (Resolve-DNSName ($AKS.FQDN)).ip4address
                    ServiceCidr       = $AKS.NetworkProfile.ServiceCidr
                    DNSServiceIP      = $AKS.NetworkProfile.DNSServiceIP
                    DockerBridgeCidr  = $AKS.NetworkProfile.DockerBridgeCidr
                    Location          = $AKS.location
                    Subscription      = $Sub.Name
                }
                $AKSObj = New-Object -TypeName PSObject -Property $AKSProps
                $AKSArr += $AKSObj
            }
        }
    
        # FRONT DOOR
        $ProviderName = "Microsoft.Network"
        $ProviderCheck = CheckProvider -provider $Providername -ProviderList $Providers
        if ($providerCheck -eq $true)
        {
            Foreach ($FD in (Get-AzFrontDoor))
            {
                $FDProps = [ordered]@{
                    Name         = $FD.Name
                    Type         = $FD.Type
                    Endpoints    = $FD.FrontendEndpoints.hostname -join ";"
                    Subscription = $Sub.Id
                }
                $FDObj = New-Object -TypeName PSObject -Property $FDProps
                $FDArr += $FDObj
            }
        }
     }
} # Select-AzSubscription

# Export to CSV
$IaaSArr | Export-CSV -Append -NoTypeInformation $ExportPath"IaaS.csv"
$WebAppsArr | Export-CSV -Append -NoTypeInformation $ExportPath"webapps.csv"
$SQLServerArr | Export-CSV -Append -NoTypeInformation $ExportPath"sqlserver.csv"
$StorageArr | Export-CSV -Append -NoTypeInformation $ExportPath"storage.csv"
$KVarr | Export-CSV -Append -NoTypeInformation $ExportPath"kv.csv"
$APIMgmtarr | Export-CSV -Append -NoTypeInformation $ExportPath"apimgmt.csv"
$CGArr | Export-CSV -Append -NoTypeInformation $ExportPath"containergroups.csv"
$CRArr | Export-CSV -Append -NoTypeInformation $ExportPath"containerreg.csv"
$AKSArr | Export-CSV -Append -NoTypeInformation $ExportPath"aks.csv"
$FDarr | Export-CSV -Append -NoTypeInformation $ExportPath"FrontDoor.csv"
