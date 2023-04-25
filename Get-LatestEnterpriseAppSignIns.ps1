#Updated 9 2021

$timestamp = Get-Date -UFormat "%Y%m%d"
$Path = "C:\tmp\"+$timestamp+"_AzureADAppsAll.csv"

# Get only enterprise apps
$AzureADApps = Get-AzureADServicePrincipal -All $true

# Loop through each Enterprise App and collect data
foreach ($AzureADApp in $AzureADApps)
{
    #$Filter = "appId eq '" + $enterpriseapp.appid + "'"
    #$SignIns = Get-AzureADAuditSignInLogs -filter $Filter
    
    $AppProps = [ordered]@{
        "DisplayName"    = $AzureADApp.DisplayName
        #"SignInCount"    = $SignIns.Count
        #"LatestSignIn"   = ($SignIns | Select-Object -first 1).createdDateTime
        #"LatestSPSignIn" = ""
        "ReplyURLs"      = $AzureADApp.ReplyUrls -join ","
        "Tags"           = $AzureADApp.Tags -join ","
        "AccountEnabled" = $AzureADApp.AccountEnabled
        "PublisherName"  = $AzureADApp.PublisherName
        "SPNames"        = $AzureADApp.ServicePrincipalNames -join ','
        "ObjectId"       = $AzureADApp.ObjectId
        "AppId"          = $AzureADApp.AppId
    }
    $AppObj = New-Object -TypeName PSObject -Property $AppProps
    $AppObj | Export-Csv -Append -NoTypeInformation $Path
}
