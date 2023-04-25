# Text file containing Application Ids (Download report from Portal)
$AppIds = Get-Content C:\tmp\appids.txt

foreach ($Appid in $AppIds)
{
    $app = get-azureadapplication -filter "AppId eq '$appId'"
    
    # If results not None
    If ($app)
    {
        # Get Ownership
        $Owner = Get-AzureADApplicationOwner -ObjectId $App.ObjectId

        $AppProps = [ordered]@{
            DisplayName      = $App.DisplayName
            AppId            = $App.AppId
            ObjectId         = $App.ObjectId
            Owner            = $Owner.DisplayName -join ","
        }
   
   }else{
            $AppProps = [ordered]@{
            DisplayName      = ''
            AppId            = $Appid
            ObjectId         = ''
            Owner            = ''
        }
   }
   
   $AppObj = New-Object -TypeName PSObject -Property $AppProps
   $AppObj
   $AppObj | export-csv -NoTypeInformation -Append c:\tmp\appids.csv
}