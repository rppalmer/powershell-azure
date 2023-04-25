<# 
.SYNOPSIS 
    Runs a simple port scan on Azure Public IPs
.DESCRIPTION 
    Pulls down a list of active Public IPs from Azure and then runs an
    nmap scan on each to determine open ports. Results are then emailed.
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  7/2/2021
    Purpose/Change: Initial script development
    
    ### nmap parameters ###
    # --open : only return open ports
    # -n     : don't resolve hostnames
    # -Pn    : Treat all hosts as onliny
    # -sS    : TCP SYN
    # --max-retries 3   : Caps number of port scan probe retransmissions
    # --max-rtt-timeout : Specifies probe round trip time
    # --initial-rtt-timeout 500ms
    # --defeat-rst-ratelimit : ignore rate limit (speeds up scan)
    # --min-rate 450         : minimum packets per second
    # --max-rate 15000       : maximum packets per second
    # --disable-arp-ping     : don't arp ping

#> 

$automationAccount      = "xxx" 
$aaResourceGroup        = "xxx"
$allActiveSubscriptions = Get-AzSubscription | Where-Object {$_.State -eq "Enabled"}

# log start time of script
$ScriptStartTime = (Get-Date)                                                                           

# Connect with Managed Identity
Connect-AzAccount -Identity                                                                                

# Set to true to send alert
$SendMailCheck = $False                                                                               

# Sensitive Ports that will be alerted on
$alertPorts = ($AlertPorts = @("21","22","23","25","110","111","135","139","143","389","445","515","993","1270","1433","1723","3306","3389","5900","5985","5986","8080","9100","27017")) -join ","   

# Excluded hosts (name of the IP object)
$ExcludeHosts = @("vm_name")   

# WAN IPs / Provided by Network Team. Needs to be periodically updated.
$WANIpAddrs = @("")

# Log Function
Function logFunction
{
    param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string] $message,
        [Parameter(Mandatory=$true, Position=1)]
        [string] $logName
    )
    
    $logFilePath = "C:\ScriptLogs\Alert-RestrictedPorts\"
    
    if ( -not (Test-path $logFilePath))
    {
        New-Item -Type directory $logFilePath
    }
    
    $timestamp = Get-Date -UFormat "%Y%m%dT%I%M%S"
    "$timestamp : $message" | out-file -NoClobber -Append "$logFilePath$(Get-Date -UFormat "%Y%m%d")-$logName.log"
}

logFunction -message "Collecting Public IPs from all available subscriptions..." -logname "Alert-RestrictedPorts"

# Loop through all subs and collect public IPs that are enabled
$AllIps = @()
Foreach ($Sub in $allActiveSubscriptions)
{
    
    Select-AzSubscription -Subscriptionid $Sub.id | out-null
    $AllIPs += Get-AzPublicIpAddress | Where-Object {$_.ipaddress -ne "Not Assigned"} | Select-Object ipaddress,id,name,resourcegroupname,location
    
}

# Create a single array that includes Azure and WAN ports
Foreach ($WANIpAddr in $WANIpAddrs)
{
    $AllIPs += New-Object -typename psobject -property @{'IPAddress'=$wanIpAddr}
}

logFunction -message "Public IP collection complete." -logname "Alert-RestrictedPorts"

# Log the start of the script
$ScanStartTime = (Get-Date)

# some high level stats
$TotalIPs = ($AllIps.ipaddress).count
logFunction -message "Total IPs being scanned: $TotalIPs" -logname "Alert-RestrictedPorts"                                                   
$ScannedIps = $AllIps.ipaddress -join ','
logFunction -message "Scanning IPs: $ScannedIps" -logname "Alert-RestrictedPorts"                                                   

# Loop through all collected IPs and scan
$NmapResultArr = @()
foreach ($IP in $AllIPs)
{
    
    logFunction -message "Scan started for $($IP.name) $($IP.ipaddress)" -logname "Alert-RestrictedPorts"

    # Scan the IP
    $nmapResults = & "C:\Program Files (x86)\Nmap\nmap.exe" @('--open','-n','-Pn','-sS','-p',$AlertPorts,'--max-retries','3','--max-rtt-timeout','2000ms',`
    '--initial-rtt-timeout','500ms','--defeat-rst-ratelimit','--min-rate','450','--max-rate','15000','--disable-arp-ping',$IP.ipaddress)
    
    # select only lines beginning with a number to extract port
    $NmapResults = $NmapResults | Select-String -Pattern "^\d" 
      
    # If results returned (listening on restricted ports) then collect data if not on exclusion list
    if ($NmapResults -and $excludeHosts -notcontains $IP.Name)
    {
        # Set sendmail to $true
        $sendMailCheck = $True

        foreach ($NmapResult in $NmapResults)
        {
            $NmapResultProps = [ordered]@{
                Name            = $IP.Name
                RGName          = $IP.ResourceGroupName
                ipAddress       = $IP.IPAddress
                Port            = (($nmapResult -split "\s+")[0])
                State           = (($nmapResult -split "\s+")[1])
                Service         = (($nmapResult -split "\s+")[2])
                Location        = $IP.location
                Subscription    = ($allActiveSubscriptions | where {$_.id -match ($IP.id -split "/")[2]} | select name).name
                #Owner           = $IP.Tags['owner']
                #Environment     = $IP.Tags['environment']
                #Application     = $IP.Tags['application']
                #CostCenter      = $IP.Tags['costCenter']
            }

            # log details
            logFunction -message "Restricted port detected for $($IP.name) $($IP.ipaddress) listening on => $((($nmapResult -split "\s+")[0]))" -logname "Alert-RestrictedPorts"

            $NmapResultObj = New-Object -TypeName PSObject -Property $NmapResultProps
            $NmapResultArr += $NmapResultObj
                  
        }
    }
}
$ScanEndTime = (Get-Date)
logFunction -message $('Scan Complete. Total Execution Time: {0:mm} min {0:ss} sec' -f ($ScanEndTime-$ScanStartTime)) -logname "Alert-RestrictedPorts"

# Email Alert / Data for report
$Header = @"
<style>
@charset "UTF-8";
table {font-family:Calibri;border-collapse:collapse;background-color: #f1f1f1}
td
{font-size:1em;border:1px solid #2191ca;padding:5px 5px 5px 5px;}
th
{font-size:1em;border:1px solid #2191ca;text-align:center;padding-top:px;padding-bottom:4px;padding-right:4px;padding-left:4px;background-color:#2191ca ;color:#ffffff;}
</style>
<h2 style="Calibri";> Alert: Public IPs listening on Restricted Ports </h2>
If this is expected, add the object name to the list of exclusions in the runbook (https://portal.azure.com) <br>
<br> <b> Port List:</b> $AlertPorts 
<br> <b> Total IPs scanned: </b> $TotalIPs <br><br>
"@

$emailBody += $header
$emailBody += $NmapResultArr | ConvertTo-HTML
    
If ($sendMailCheck -eq $True)
{    
    # Set Context
    $AzureContext = Set-AzContext -SubscriptionId "xxx"
    
    # Email Triggered
    logFunction -message "Email alert triggered!" -logname "Alert-RestrictedPorts"
    
    # Send via SendGrid
    $params = @{
        "ToEmailAddress"="xxx";
        "FromEmailAddress"="xxx";
        "Subject"="Alert: Sensitive ports on public assets - " + (Get-Date -DisplayHint Date);
        "Body"= $emailBody;
    }

    ## Set Context of Runbook and call Set-SendGridMessage runbook and pass params for email
    $AzureContext = Set-AzContext -SubscriptionId "xxx"
    Start-AzAutomationRunbook  –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $aaResourceGroup  –Parameters $params
} Else {
    logFunction -message "Email alert not triggered, no hosts found listening on sensitive ports." -logname "Alert-RestrictedPorts"
}

# Capture endTime and log duration
$ScriptEndTime = (Get-Date)
logFunction -message $('Script run complete. Total Execution Time: {0:mm} min {0:ss} sec' -f ($ScriptEndTime-$ScriptStartTime)) -logname "Alert-RestrictedPorts"
