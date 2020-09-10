<#
.SYNOPSIS
    Parses NSG flowlogs stored in Azure Blob storage

.DESCRIPTION
    This script extracts traffic flows from NSG Flow logs and converts from JSON to a more readable format. 

.PARAMETER StorageAccountName
    Required.  The name of the storage account where the NSG flowlogs are stored.

.PARAMETER ResourceGroup
    Required.  The name of the storage account resource group.

.PARAMETER DisplayInTerminal
    Optional.  When set logs will display on screen instead of exporting to a file. Default: Exports to file.

    THIS PARAMETER CAN CAUSE A LOT OF DATA TO DISPLAY TO THE SCREEN.

.PARAMETER Path
    Optional.  The path to export results. If no parameter is specified the script will save to script root.

.PARAMETER TargetNSGs
    Optional.  Target a specific NSG or NSGs. If not set will loop through all NSGs in a storage account.

.PARAMETER FlowDirection
    Optional. 

.PARAMETER Hours
    Optional.  The number of hours to look back. Default: 1

.EXAMPLE
    .\Get-NSGFlowLogs.ps1 -StorageAccountName app01sa -Resourcegroup app01-rg

    The above will loop through all flow logs in the specified storage account and export to folder where script is running

.EXAMPLE
    .\Get-NSGFlowLogs.ps1 -StorageAccountName app01sa -Resourcegroup app01-rg -Path c:\Temp -FlowDirection In

    The above will loop through all flow logs in the specified storage account, export to c:\Temp, and only show inbound traffic flows.

.EXAMPLE
    .\Get-NSGFlowLogs.ps1 -StorageAccountName app01sa -Resourcegroup app01-rg -DisplayInTerminal -FlowDirection both 

    The above will loop through all flow logs in the specified storage account, export to script root, display results in terminal, and show inbound and outbound flows.

.EXAMPLE
    .\Get-NSGFlowLogs.ps1 -StorageAccountName app01sa -Resourcegroup app01-rg -Hours 2 -TargetNSG @("app01-subnet1-nsg","app01-subnet2-nsg")

    The above will loop through all flow logs in the specified storage account for the listed NSGs, get the past two hours of logs and export to script root.

.NOTES

    Requires: Az.Storage
#>

Function Get-NSGFlowLogs
{

    param (
        [Parameter(Mandatory=$true, HelpMessage= 'Provide the name of the storage account')] 
        [string] $StorageAccountName,
        [Parameter(Mandatory=$true, HelpMessage= 'Provide the name of the storage account resource group')] 
        [string] $ResourceGroup,
        [Parameter(Mandatory=$false, HelpMessage= 'Display results on screen. Default: False / Export to file')] 
        [switch] $DisplayInTerminal=$False,
        [Parameter(Mandatory=$false, HelpMessage= 'Provide path to save results. Default: Script Directory')] 
        [string] $Path=$PSScriptRoot,
        [Parameter(Mandatory=$false, HelpMessage= 'Target specific NSGs or loop through all in storage account. Default: all')] 
        [string[]] $TargetNSGs = "all",
        [Parameter(Mandatory=$false, Helpmessage= 'Display direction: in, out, both. Default: In')] 
        [string] $FlowDirection = "in",
        [Parameter(Mandatory=$false, Helpmessage= 'Number of hours to display, Default = 1')] 
        [int] $Hours = 1
    )

    # Assume going in that requirements have been met unless otherwise determined
    $RequirementsMet = $true
    $RequiredModulesMet = $true

    # List of modules that are required
    $Modules = @(
        @{ Name = 'Az.Storage'; Version = [System.Version]'1.5.1' }
    )

    # Check to confirm that dependency modules are installed
    Function CheckDependencyModules {
        Write-Host ("[*] Checking for presence of required modules.")
        foreach ($Module in $Modules) {
            if ([string]::IsNullOrEmpty($Module.Version)) {
                Write-Host ("[*] Checking for module '{0}'." -f $Module.Name)
            } else {
                Write-Host ("[*] Checking for module '{0}' of at least version '{1}'." -f $Module.Name, $Module.Version)
            }
            $LatestVersion = (Find-Module -Name $Module.Name).Version
            $CurrentModule = Get-Module -Name $Module.Name -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            if ($CurrentModule) {
                Write-Host ("[*] Found version '{0}' of module '{1}' installed." -f $CurrentModule.Version, $CurrentModule.Name)
                if ($LatestVersion) {
                    if ($LatestVersion.Version -gt $CurrentModule.Version) {
                        Write-Host ("[!] There is a newer version of module '{0}'.  Version '{1}' is available." -f $LatestVersion.Name, $LatestVersion.Version)
                    }
                }
                if ($CurrentModule.Version -lt $Module.Version) {
                    Throw ("[!] Installed version '{0}' of module '{1}' does not meet minimum requirements." -f $CurrentModule.Version, $CurrentModule.Name)
                    $script:RequirementsMet = $false
                    $script:RequiredModulesMet = $false
                }
            } else {
                Throw ("[!] Could not find module '{0}' installed." -f $Module.Name)
                $script:RequirementsMet = $false
                $script:RequiredModulesMet = $false
            }
        }
    }

    Function CheckDependencies {
        Write-Host ("[*] Checking for dependencies.")
        CheckDependencyModules
    }

    CheckDependencies

    Function ConvertDate {
        param (
            [Parameter(Mandatory=$True)]
            [string] $blobtime
        )

        $convertDate = $blobtime.split('/')[0].split('=')[1]+"-"+`
        $blobtime.split('/')[1].split('=')[1]+"-"+$blobtime.split('/')[2].split('=')[1]+"T"+`
        $blobtime.split('/')[3].split('=')[1]+":"+$blobtime.split('/')[4].split('=')[1]
        
        return $convertDate
    }

    # Container name used by NSG flow logs (normally default)
    $ContainerName = "insights-logs-networksecuritygroupflowevent"

    # Get storage account key
    $StorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroup -Name $storageAccountName).Value[0]
    $ctx = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey

    # get all blobs
    Write-host "[*] Getting blob data..."
    $blobs = Get-AzStorageBlob -Context $ctx -Container $ContainerName

    $nsgList = @()
    # Checks whether a specific NSG should be targeted or loop through them all
    if ($targetNSGs -eq "all")
    {
        Write-Host "[*] Specific NSG not targeted, looping all. Creating list of NSGs..."
        foreach ($blob in $blobs) # Create a unique list of NSGs
        {
            $blobNsg = ($blob.name -split ('/'))[8]
            if ($nsgList -notcontains $blobNsg){$nsgList += $blobNsg}
        }   
    } else {
        $nsgList += $targetNSGs
    }

    Write-Host "[*] Target NSG(s): $nsgList"

    # loop through unique NSGs 
    foreach ($nsg in $nsgList)
    {
        # get a list of dates pertaining to this NSG
        $dateList = @()
        foreach ($blob in $blobs)
        {
            $blobSplit = $blob.name.split('/')
            $blobNsg = $blobSplit[8] 
            $blobTime = $blobsplit[9..13] -join '/'

            # Create an array containing a list of dates associated with this NSG
            if ($blobNsg -eq $nsg){$dateList += $blobTime}        
        }

        # sort in descending order and then choose last 0 to X hours of blobs
        if ($dateList) {
            $dateList = $dateList | Sort-Object -Descending -Unique
            $dateList = $dateList[0..($Hours - 1)]
        }

        # Loop through the list of dates
        foreach ($date in $dateList) # loop through dates
        {
            
            foreach ($blob in $blobs)
            {
                $blobSplit = $blob.name.split('/')          # split array
                $blobNsg = $blobSplit[8]                    # get the name of nsg, position 8
                $blobTime = $blobsplit[9..13] -join '/'     # parse time out of blob name
                
                $blobMatches = @() # Stores any results where the nsgname and dates match

                if (($blobNsg -eq $nsg) -and ($blobTime -eq $date))
                {
                    $blobMatches += $blob.name # match found, store in $blobMatches
                }

                foreach ($blobName in $blobMatches) # loop through the matches
                {
                    # set temporary location to download json data
                    $localFileName = "$env:TEMP\flowlog_tmp.json"
                    If (Test-path $localFileName) { Remove-Item $localFileName }
                    
                    # Download blob content to local file
                    Get-AzStorageBlobContent -Container $ContainerName -Blob $blobName -Destination $localfileName -Context $ctx | out-null
                    
                    # Convert to json to powershell object
                    $blobContent = Get-Content $localFileName | ConvertFrom-Json
                    
                    # loop through each json file and parse out information
                    $recordCollection = @()
                    foreach ($record in $BlobContent.records)
                    {
                        foreach ($rule in $record.properties.flows)
                        {
                            foreach ($flow in $rule.flows)
                            {
                                foreach ($flowtuple in $flow.flowtuples)
                                {
                                    
                                    $tupleSplit = $flowtuple -split ','
                                    $tupleLoop = "" | Select-Object time, mac, rule, action, direction, protocol, sourceIP, destIP, sourcePort, destPort
                                    
                                    if (($FlowDirection -eq "in") -and ($tupleSplit[6] -eq "I"))
                                    {
                                        $tupleLoop.time = $record.time
                                        $tupleLoop.mac = $flow.mac
                                        $tupleLoop.rule = $rule.rule
                                        $tupleLoop.action = $action.action
                                        $tupleLoop.sourceIP = $tupleSplit[1]
                                        $tupleLoop.destIP = $tupleSplit[2]
                                        $tupleLoop.sourcePort = $tupleSplit[3]
                                        $tupleLoop.destPort = $tupleSplit[4]
                                        $tupleLoop.protocol = $tupleSplit[5]
                                        $tupleLoop.direction = $tupleSplit[6]
                                        $tupleLoop.action = $tupleSplit[7]

                                        $recordCollection += $tupleLoop
                                        
                                    } Elseif (($FlowDirection -eq "out") -and ($tupleSplit[6] -eq "O"))
                                    {
                                        $tupleLoop.time = $record.time
                                        $tupleLoop.mac = $flow.mac
                                        $tupleLoop.rule = $rule.rule
                                        $tupleLoop.action = $action.action
                                        $tupleLoop.sourceIP = $tupleSplit[1]
                                        $tupleLoop.destIP = $tupleSplit[2]
                                        $tupleLoop.sourcePort = $tupleSplit[3]
                                        $tupleLoop.destPort = $tupleSplit[4]
                                        $tupleLoop.protocol = $tupleSplit[5]
                                        $tupleLoop.direction = $tupleSplit[6]
                                        $tupleLoop.action = $tupleSplit[7]
                                        
                                        $recordCollection += $tupleLoop

                                    } Elseif ($FlowDirection -eq "both")
                                    {
                                        $tupleLoop.time = $record.time
                                        $tupleLoop.mac = $flow.mac
                                        $tupleLoop.rule = $rule.rule
                                        $tupleLoop.action = $action.action
                                        $tupleLoop.sourceIP = $tupleSplit[1]
                                        $tupleLoop.destIP = $tupleSplit[2]
                                        $tupleLoop.sourcePort = $tupleSplit[3]
                                        $tupleLoop.destPort = $tupleSplit[4]
                                        $tupleLoop.protocol = $tupleSplit[5]
                                        $tupleLoop.direction = $tupleSplit[6]
                                        $tupleLoop.action = $tupleSplit[7]
                                        
                                        $recordCollection += $tupleLoop
                                    }
                                }
                            }
                        }
                    }
                    
                    # If option to display on screen is not set
                    if ($DisplayInTerminal -eq $False)
                    {
                        # Create folder if it doesn't exist
                        if (!(Test-Path $Path))
                        {
                            Write-Host ("[*] Creating folder '{0}'." -f $Path)
                            $null = New-Item -ItemType Directory -Path $Path
                        }
                        $timestamp = Get-Date -UFormat "%Y%m%d"
                        $outFile = $Path+"\flowlog_"+$nsg+"_"+$timestamp+".csv"
                        $recordCollection | export-csv -append -NoTypeInformation $outfile
                    } else {
                        Write-Host ""
                        Write-Host "   NSG Name:" `t $nsg -ForegroundColor Blue
                        Write-Host "   MAC Address: " $flow.mac -ForegroundColor Blue
                        Write-Host "   Date: " `t $(ConvertDate -blobtime $date) -ForegroundColor Blue
                        $recordCollection | Format-Table -auto -wrap
                    }
                    
                }
            }
            if ($DisplayInTerminal -eq $False)
            {
                Write-host "[*] Data exported for $nsg to $outFile"
            }
            
        }
    }
}
