$excel = Open-ExcelPackage -Path "C:\tmp\diffv3\azure-server-list-master.xlsx"
$worksheet = $excel.Workbook.Worksheets['Virtual']

function updateCell {

    param($ColumnText, $RowText, $updateText)

    foreach ($column in 1..$($worksheet.Dimension.Columns))
    {
        if ($worksheet.Cells[1,$column].value -match $ColumnText)
        {
            foreach ($row in 1..$($worksheet.Dimension.Rows))
            {
                if ($($worksheet.Cells[$row,1].value) -match $RowText)
                {
                    $worksheet.Cells[$row,$column].value = $updateText
                }
            }       
        }
    }
}

function addEntry {

    # iterate through rows and check if hostname exists
    foreach ($row in 1..$($worksheet.Dimension.Rows))
    {
        if ($($worksheet.Cells[$row,1].value) -match $vm.name)
        {
            Write-host "Found entry, exit function"
            Return
        }
    }
    write-host "hostname not found, adding entry"
    # If hostname doesn't already exist, start adding properties to new row

    $row = $($worksheet.Dimension.Rows) + 1
    
    $worksheet.Cells[$row,1].value = $vm.name
    $worksheet.Cells[$row,2].value = $vm.StorageProfile.OsDisk.OsType 
    $worksheet.Cells[$row,3].value = "hpfc.local"
    $worksheet.Cells[$row,4].value = $vm.PowerState
    $worksheet.Cells[$row,5].value = $vm.tags['application']
    $worksheet.Cells[$row,7].value = $vm.tags['environment']
    $worksheet.Cells[$row,8].value = $vm.tags['owner']
    $worksheet.Cells[$row,9].value = $vm.tags['costCenter']
    $worksheet.Cells[$row,11].value = $vm.HardwareProfile.VmSize

    # VMsize
    $vmsize = Get-AzVMSize -Location $vm.Location |Where-Object {$_.name -eq $vm.HardwareProfile.vmsize}
    $worksheet.Cells[$row,14].value = $vmsize.numberOfCores # requires Get-VMSize
    $worksheet.Cells[$row,13].value = $vmsize.MemoryInMB # requires Get-VMSize
    
    # IP Addresses
    Try
    {
        $vmNetworkInterfaces = Get-AzNetworkInterface -ResourceId $vm.networkprofile.networkinterfaces.id
        $publicIPAddress = (Get-AzPublicIpAddress -Name ($vmNetworkInterfaces.IpConfigurations.publicipaddress.id).split("/")[8]).IpAddress
        $worksheet.Cells[$row,14].value = $vmNetworkInterfaces.ipconfigurations.privateipaddress
        $worksheet.Cells[$row,15].value = $publicIPAddress    
    }
    Catch
    {
        $vmNetworkInterfaces = Get-AzNetworkInterface -ResourceId $vm.networkprofile.networkinterfaces.id
        $worksheet.Cells[$row,14].value = $vmNetworkInterfaces.ipconfigurations.privateipaddress
        $worksheet.Cells[$row,15].value = "Not Assigned"
    }
    $worksheet.Cells[$row,16].value = $vm.StorageProfile.osdisk.ManagedDisk.StorageAccountType
    $worksheet.Cells[$row,17].value = $vm.StorageProfile.osdisk.DiskSizeGB
    $worksheet.Cells[$row,18].value = $vm.StorageProfile.DataDisks[0].DiskSizeGB
    $worksheet.Cells[$row,19].value = $vm.StorageProfile.DataDisks[0].ManagedDisk.StorageAccountType
    $worksheet.Cells[$row,20].value = $vm.StorageProfile.DataDisks[1].DiskSizeGB
    $worksheet.Cells[$row,21].value = $vm.StorageProfile.DataDisks[1].ManagedDisk.StorageAccountType
    $worksheet.Cells[$row,22].value = $vm.StorageProfile.DataDisks[2].DiskSizeGB
    $worksheet.Cells[$row,23].value = $vm.StorageProfile.DataDisks[2].ManagedDisk.StorageAccountType
    $worksheet.Cells[$row,24].value = $vm.StorageProfile.DataDisks[3].DiskSizeGB
    $worksheet.Cells[$row,25].value = $vm.StorageProfile.DataDisks[3].ManagedDisk.StorageAccountType
    $worksheet.Cells[$row,26].value = $vm.location
    $worksheet.Cells[$row,27].value = ($vm.id -split ("/"))[2] 
}

foreach ($vm in (Get-AzVM -status))
{
    #addEntry $vm
}


Close-ExcelPackage $excel