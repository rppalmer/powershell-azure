<#
    .Author
    Trevor Sullivan <pcgeek86@gmail.com>

    .Links
    http://trevorsullivan.net
    http://twitter.com/pcgeek86

    .Description
    This PowerShell script uses the Microsoft Azure PowerShell module along with PowerShell
    Background Jobs to list out all of the Azure Storage blob containers in the currently 
    selected Azure platform subscription. The results are displayed using the Out-GridView
    command, and each Storage Container object has the StorageAccountName property added to it.

    If you have a large number of Azure Storage Accounts in your Azure subscription, then
    you will likely benefit from using PowerShell Background Jobs to enumerate the blob
    containers in each Azure Storage Account.
#>

### Clean up background jobs (POTENTIALLY DAMAGING)
Get-Job | Remove-Job -Force;

### Create an empty array to hold the PowerShell Background Jobs
$JobList = @();

### Obtain a list of Azure Storage Accounts in the currently selected Azure platform subscription
$StorageAccountList = Get-AzureStorageAccount;

### Write out the start time, before we begin retrieving the Azure blob containers
Write-Host -Object (Get-Date);

foreach ($StorageAccount in $StorageAccountList) {
    ### Declare a PowerShell ScriptBlock that retrieves the Azure blob storage containers from each Storage Account
    $ScriptBlock = {
        $StorageAccount = $args[0];
        $StorageKey = Get-AzureStorageKey -StorageAccountName $StorageAccount.StorageAccountName;
        $StorageContext = New-AzureStorageContext -StorageAccountName $StorageKey.StorageAccountName -StorageAccountKey $StorageKey.Primary;
        
        Get-AzureStorageContainer -Context $StorageContext | Add-Member -MemberType NoteProperty -Name StorageAccountName -Value $StorageContext.StorageAccountName -PassThru;
    }
    ### Invoke a PowerShell Background Job for the current Storage Account being iterated over
    $JobList += Start-Job -ScriptBlock $ScriptBlock -ArgumentList $StorageAccount -Name $StorageAccount.StorageAccountName -InitializationScript { Import-Module -Name Azure; };
}

### Wait for all of the PowerShell Background Jobs to complete
Wait-Job -Job $JobList;

### Write out the completion time, after all blob containers have been retrieved
Write-Host -Object (Get-Date);

### Receive the results of the jobs
$ContainerList = Receive-Job -Job $JobList;

$ContainerList | 
    Select-Object -Property StorageAccountName, Name, PublicAccess, LastModified | 
    Out-GridView -Title ('All Azure Storage Blob Containers in Subscription: {0}' -f (Get-AzureSubscription -Current).SubscriptionName);