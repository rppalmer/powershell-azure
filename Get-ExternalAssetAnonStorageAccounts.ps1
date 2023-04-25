# List storage account containers with anonymous access

#$ContainerArr= @()
Foreach ($Sub in Get-AzSubscription)
{
    
    Select-AzSubscription -SubscriptionId $Sub.id

    # Loop through storage accounts, grab the key and set context for storage account, get its containers
    foreach($SA in (Get-AzStorageAccount))
    {
        
        $Key = Get-AzStorageAccountKey -StorageAccountName $SA.StorageAccountName -ResourceGroupName $SA.ResourceGroupName
        $Context = New-AzStorageContext -StorageAccountName $SA.StorageAccountName -StorageAccountKey $key[0].Value
        $Containers = Get-AzStorageContainer -Context $context
        
        foreach ($Container in $Containers)
        {
            if ($Container.PublicAccess -ne "Off")
            {               
                $ContainerProps = [ordered]@{
                    SAName          = $SA.StorageAccountName
                    SAPublicAccess  = $SA.AllowBlobPublicAccess
                    RGName          = $SA.ResourceGroupName
                    Location        = $SA.Location
                    ContainerName   = $Container.Name
                    LastModified    = $Container.LastModified
                    PublicAccess    = $Container.PublicAccess
                    Subscription    = $Sub.name
                    Owner           = $SA.Tags['owner']
                    Environment     = $SA.Tags['environment']
                    Application     = $SA.Tags['application']
                    CostCenter      = $SA.Tags['costCenter']
                    
                }

                $ContainerObj = New-Object -TypeName PSObject -Property $ContainerProps
                $ContainerObj | export-csv -NoTypeInformation -append c:\tmp\anonstorage.csv
            }        
        }
    }
}


