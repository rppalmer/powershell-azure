############################
## Source Virtual machine ##
############################
$SourceLocation     = "West US"
$SourceSubId        = "xxx"
$SourceVMName       = "xxx"
$SourceRGName       = "xxx"
$SourceOSSnapName   = "$SourceVMName-snap-osdisk"
$SourceDDSnapName   = "$SourceVMName-snap-datadisk"
$SourceOS           = "linux" # Option windows/linux

############################
## Target Virtual Machine ##
############################
$TargetLocation     = "West US"
$TargetSubId        = "xxx"
$TargetVMName       = "xxx"
$TargetRGName       = "xxx"
$TargetVMSize       = "Standard_DS1_v2"
# East
# $TargetVNetName     = "xxx" 
# $TargetVNetRGName   = "xxx"
# $TargetSubnetName   = "xxx"
# West
$TargetVNetName     = "xxx" 
$TargetVNetRGName   = "xxx"
$TargetSubnetName   = "xxx"
$TargetOSSnapName   = "$SourceVMName-snap-osdisk"
$TargetDDSnapName   = "$SourceVMName-snap-datadisk"

Write-Host -ForegroundColor DarkRed  "`n****************************************************************************"
Write-host -ForegroundColor DarkRed  "                           !! ATTENTION !!                                    "
Write-Host -ForegroundColor DarkRed  "****************************************************************************"
Write-host -ForegroundColor DarkRed  "WHEN MIGRATION IS SUCCESSFUL MANUAL CLEANUP IS REQUIRED"
Write-host -ForegroundColor DarkRed  "SOURCE RESOURCES AND SNAPSHOTS AND DESTINATION SNAPSHOTS ARE NOT AUTO REMOVED"
Write-host -ForegroundColor DarkRed  "REMEMBER TO REMOVE OLD BACKUPS`n"
Start-Sleep 2

# Check target subscription for existance of networking before continuing
$TargetSub = Set-AzContext $TargetSubId

Write-host "[*] Connecting to Target subscription to check target VNet and Subnet" $TargetSub.Subscription.Name

# Get destination vnet for later use
try{
    $TargetVNet = Get-AzVirtualNetwork -Name $TargetVNetName -ResourceGroupName $TargetVNetRGName -ErrorAction Stop
    Write-host "[*] Destination VNet Ok!"
}catch{
    Write-host "[!] Check that the target vnet exists and that the TargetVNetName variable is corect, exiting..."
    Exit
}

# Get destination subnet for later use
try{
    $TargetSubnet = Get-AzVirtualNetworkSubnetConfig -name $TargetSubnetName -VirtualNetwork $TargetVNet -ErrorAction Stop
    Write-host "[*] Destination Subnet Ok!"
}catch{
    Write-host "[!] Check that the target subnet exists and that the TargetSubnetName variable is corect, exiting..."
    Exit
}

# Set initial sub
$SourceSub = Set-AzContext $SourceSubId
Write-host "[*] Connecting to Source subscription" $SourceSub.Subscription.Name

# Take snapshot of target VM
Write-host "[*] Getting data from $SourceVMName"
$SourceVM = Get-AzVM -ResourceGroupName $SourceRGName -Name $SourceVMName
$SourceOSSnapshotConfig =  New-AzSnapshotConfig -SourceUri $SourceVM.StorageProfile.OsDisk.ManagedDisk.Id -Location $SourceLocation -CreateOption copy

# Check that $SourceOS variable matches VM OS
if ($SourceOS -ne $SourceVM.StorageProfile.OsDisk.OsType)
{
    Write-host "[!] SourceOS variable does not match VM OS, exiting..."
    Exit
}

Write-host "[*] Taking OS Disk snapshot ->" $SourceOSSnapName
New-AzSnapshot -Snapshot $SourceOSSnapshotConfig -SnapshotName $SourceOSSnapName -ResourceGroupName $SourceRGName
$SourceOSSnapshot = Get-AzSnapshot -SnapshotName $SourceOSSnapName -ResourceGroupName $SourceRGName

# If data disks found, take snapshots
$SourceDDSnapshots = @()
if ($SourceVM.StorageProfile.DataDisks)
{
    Write-Host "[!] VM has data disks"
    $x = 0
    foreach ($DataDisk in ($SourceVM.StorageProfile.DataDisks.ManagedDisk))
    {
        Write-host "[*] Found disk ->" ($DataDisk.id -Split "/")[-1]
        $SourceDDSnapshotConfig = New-AzSnapshotConfig -SourceUri $DataDisk.Id -Location $SourceLocation -CreateOption copy
        
        Write-host "[*] Taking Snapshot ->" ($DataDisk.id -Split "/")[-1] "$SourceDDSnapName-$x"
        New-AzSnapshot -Snapshot $SourceDDSnapshotConfig -SnapshotName $SourceDDSnapName-$x -ResourceGroupName $SourceRGName
        
        Write-Host "[*] Storing -> $SourceDDSnapName-$x"
        $SourceDDSnapshots += Get-AzSnapshot -SnapshotName $SourceDDSnapName-$x -ResourceGroupName $SourceRGName
        $x++
    }
}

# Set new subscription
$TargetSub = Set-AzContext $TargetSubId
Write-host "[*] Connecting to Target subscription" $TargetSub.Subscription.Name

# Make sure resource group exists
try{
    Write-host "[*] Checking target resource group exists..."
    Get-AzResourceGroup -Name $TargetRGName -ErrorAction Stop
    Write-host "[*] Resource Group found!"
}catch{
    Write-host "[!] Target resource group not found, creating..."
    New-AzResourceGroup -Name $TargetRGName -Location $TargetLocation
}

# Migrate OS disk dnapshot to new subscription
Write-Host "[*] Creating copy of snapshot for target sub ->" $SourceOSSnapName
$TargetSnapshotConfig = New-AzSnapshotConfig -SourceResourceId $SourceOSSnapshot.Id -Location $SourceOSSnapshot.Location -CreateOption Copy
New-AzSnapshot -Snapshot $TargetSnapshotConfig -SnapshotName $SourceOSSnapName -ResourceGroupName $TargetRGName 

# Get migrated snapshot for later use (this assumes snaphot has been migated to resource group where new VM will reside)
$TargetSnapshot = Get-AzSnapshot -ResourceGroupName $TargetRGName -SnapshotName $TargetOSSnapName

# Create configuration for new os disk
$DiskConfig = New-AzDiskConfig -Location $TargetLocation -SourceResourceId $TargetSnapshot.Id -CreateOption Copy

# Create new os disk based on configuration
Write-Host "[*] Creating OS disk from snapshot -> $TargetVMName`osdisk"
$NewDisk = New-AzDisk -Disk $diskconfig -ResourceGroupName $TargetRGName -DiskName "$TargetVMName`osdisk"

# Create new VM config
$VMConfig = New-AzVMConfig -vmname $TargetVMName -VMSize $TargetVMSize

# Add VM OS Disk config to $vmconfig variable
if ($SourceOS -eq 'windows')
{
    Write-Host "[*] Adding $TargetVMName`osdisk to new Windows VM configuration..."
    $VMConfig = Set-AzVMOSDisk -VM $VMConfig -ManagedDiskId $NewDisk.id -CreateOption attach -windows
}elseif ($SourceOS -eq 'linux')
{
    Write-Host "[*] Adding $TargetVMName`osdisk to new Linux VM configuration..."
    $VMConfig = Set-AzVMOSDisk -VM $VMConfig -ManagedDiskId $NewDisk.id -CreateOption attach -linux
}

# If data disks found, Migrate data disk snapshot to new subscription
if ($SourceDDSnapshots)
{
    Write-Host "[*] Migrating data disks"
    $x = 0
    foreach ($SourceDDSnapshot in $SourceDDSnapshots)
    {
        Write-Host "[*] Making a copy ->" $SourceDDSnapshot.name
        $TargetSnapshotConfig = New-AzSnapshotConfig -SourceResourceId $SourceDDSnapshot.Id -Location $SourceDDSnapshot.Location -CreateOption Copy
        New-AzSnapshot -Snapshot $TargetSnapshotConfig -SnapshotName $TargetDDSnapName-$x -ResourceGroupName $TargetRGName 
        
        Write-Host "[*] Creating Disk Configuration -> $TargetVMName`dd$x"
        $TargetSnapshot = Get-AzSnapshot -ResourceGroupName $TargetRGName -SnapshotName $TargetDDSnapName-$x
        $DiskConfig = New-AzDiskConfig -Location $TargetLocation -SourceResourceId $TargetSnapshot.Id -CreateOption Copy
        
        Write-Host "[*] Creating Data Disk from snapshot-> $TargetVMName`dd$x"
        $NewDisk = New-AzDisk -Disk $Diskconfig -ResourceGroupName $TargetRGName -DiskName "$TargetVMName`dd$x"
        #$VMConfig = New-AzVMConfig -vmname $TargetVMName -VMSize $TargetVMSize
        $VMConfig = Add-AzVMDataDisk -VM $VMConfig -ManagedDiskId $NewDisk.id -CreateOption attach -Lun $x
        $x++
    }
}

# Create virtual network interface for new VM
$DestinationVMNic = New-AzNetworkInterface -name $TargetVMName"nic" -ResourceGroupName $TargetRGName -Location $TargetLocation -SubnetId $TargetSubnet.id

# Add networkinterface, add to $vmconfig variable
$VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -Id $DestinationVMNic.Id

# Create a new VM based on vmconfig
New-AzVM -vm $VMConfig -ResourceGroupName $TargetRGName -location $TargetLocation
