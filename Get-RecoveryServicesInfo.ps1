<# 
.SYNOPSIS 
    Report for Azure Recovery Services
.DESCRIPTION 
    Needed a better way to view Recovery Services data. This lists the backup policies and related
    information, failed backup jobs, and resources that are not being backed up.
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  10/4/2019
    Purpose/Change: Initial script development
    File Name  : Get-RecoveryServicesInfo.ps1

    To do: adjust job timestamp to EST, add azure workload backup type information
#> 

##########################
## List backup policies ##
##########################

$allBackupPolInfo = @()
Foreach ($asrVault in Get-AzRecoveryServicesVault)
{       
    $WarningPreference = 'SilentlyContinue'
    $vault = Get-AzRecoveryServicesVault -name $asrVault.name -ResourceGroupName $asrVault.ResourceGroupName
    Set-AzRecoveryServicesVaultContext -Vault $vault | out-null
    $vaultPolicies = Get-AzRecoveryServicesBackupProtectionPolicy | select *
 
    Foreach ($vaultPolicy in $vaultPolicies)
    {
        if ($vaultPolicy.BackupManagementType -eq "AzureVM")
        {
            $backupPolInfo = New-Object PSObject

            Add-Member -inputObject $backupPolInfo -memberType NoteProperty -name `
             "ASRVault" -value $asrVault.name
            Add-Member -inputObject $backupPolInfo -memberType NoteProperty -name `
             "PolicyName" -value $vaultPolicy.Name
            Add-Member -inputObject $backupPolInfo -memberType NoteProperty -name `
            "Frequency" -value (($vaultPolicy.SchedulePolicy -split ',')[0] -split ':')[1]
            Add-Member -inputObject $backupPolInfo -memberType NoteProperty -name `
            "RunTime" -value $vaultPolicy.SchedulePolicy.ScheduleRunTimes
            Add-Member -inputObject $backupPolInfo -memberType NoteProperty -name `
            "RetentionDays" -value $vaultPolicy.RetentionPolicy.DailySchedule.DurationCountInDays
            Add-Member -inputObject $backupPolInfo -memberType NoteProperty -name `
            "RetentionWeeks" -value $vaultPolicy.RetentionPolicy.WeeklySchedule.DurationCountInWeeks
            Add-Member -inputObject $backupPolInfo -memberType NoteProperty -name `
            "RetentionMonths" -value $vaultPolicy.RetentionPolicy.MonthlySchedule.DurationCountInMonths
            Add-Member -inputObject $backupPolInfo -memberType NoteProperty -name `
            "RetentionYears" -value $vaultPolicy.RetentionPolicy.YearlySchedule.DurationCountInYears
           
            $allBackupPolInfo += $backupPolInfo
        }
        elseif ($vaultPolicy.BackupManagementType -eq "AzureWorkload")
        {
          ### need to add azure workload ###
            Write-host "Policy Name: " $vaultPolicy.Name
        }  
    }
}
Write-Host "------ Backup Policy Information ------"
$allBackupPolInfo | ft -auto

################################
## Failed and Old Backup Jobs ##
################################

# for each vault set the current vault with Get-AzRecoveryServicesVault
# and get jobs where status -eq failed.
Write-Host "------ Failed Backup Jobs ------"
Foreach ($asrVault in Get-AzRecoveryServicesVault)
{
    $vault = Get-AzRecoveryServicesVault -name $asrVault.name `
    -ResourceGroupName $asrVault.ResourceGroupName
    Get-AzRecoveryServicesBackupJob -VaultId $vault.id -status Failed
}

#######################
## VMs not backed up ##KS
#######################

$allBackupNotConfigured = @()
Foreach ($vm in get-azvm)
{
    $azVmBackupStatus = Get-AzRecoveryServicesBackupStatus -ResourceId $vm.id
    
    Foreach ($azVm in $azVmBackupStatus) 
    {
        If ($AzVm.BackedUp -like "False")
        {
            $backupNotConfigured = New-Object PSObject
            
            Add-Member -inputObject $backupNotConfigured -memberType NoteProperty -name "VM_Name" -value $vm.name
            Add-Member -inputObject $backupNotConfigured -memberType NoteProperty -name "BackupStatus" -value $azVM.BackedUp
            
            $allBackupNotConfigured += $backupNotConfigured
        }
    }
}
Write-Host "------ Virtual Machines not backed up ------"
$allBackupNotConfigured | ft -auto
