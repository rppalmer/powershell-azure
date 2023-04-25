$excel = Open-ExcelPackage -Path C:\tmp\diffv3\Book1.xlsx
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

$vmsInAzure = Get-AzVM -status | Where-Object {$_.PowerState -notmatch "VM deallocated" -and ($_.name -match "ADSync" -or $_.name -match "DEV-LIS-E")} 


function addEntry {
    param($hostname, $os, $status, $environment, $owner, $costCenter, $application, $vmSize, $privateIP, $publicIP, $subscription)

    # iterate through rows and check if hostname exists
    foreach ($row in 1..$($worksheet.Dimension.Rows))
    {
        if ($($worksheet.Cells[$row,1].value) -match $RowText)
        {
            Write-host "Found entry, exit function"
            Return
        }
    }
    write-host "hostname not found, adding entry"
    # If hostname doesn't already exist, start adding properties to new row

    $row = $($worksheet.Dimension.Rows) + 1
    
    $worksheet.Cells[$row,1].value = $hostname
    $worksheet.Cells[$row,2].value = $os
    $worksheet.Cells[$row,3].value = "hpfc.local"
    $worksheet.Cells[$row,4].value = $status
    $worksheet.Cells[$row,5].value = $application
    $worksheet.Cells[$row,7].value = $environment
    $worksheet.Cells[$row,8].value = $owner
    $worksheet.Cells[$row,9].value = $costCenter
    $worksheet.Cells[$row,11].value = $vmSize
    $worksheet.Cells[$row,14].value = $privateIP
    $worksheet.Cells[$row,15].value = $publicIP
    $worksheet.Cells[$row,15].value = $subscription
    

        
}

foreach ($vm in (Get-AzVM -status | Where-Object {$_.PowerState -notmatch "VM deallocated" -and ($_.name -match "ADSync" -or $_.name -match "DEV-LIS-E")} |select *))
{
    addEntry -Hostname $vm.name 
}

#updateCell -ColumnText "Status" -RowText "azuredc07" -updateText "blah123"


#Close-ExcelPackage $excel