<# 
.SYNOPSIS 
    Automation Account job status
.DESCRIPTION 
     Automation Account job status
.NOTES   
    Version:        1.0 
    Author:         Ryan Palmer
    Creation Date:  2/17/2022
    Purpose/Change: Initial Script Creation   
#>

## Connect with Managed Identity
Connect-AzAccount -Identity
$AzureContext = Set-AzContext -SubscriptionId "xxx"

$ResourceGroup          = "xxx"
$AutomationAccountName  = "xxx"
$Lookback               = 2

$Jobs = Get-AzAutomationJob -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccountName | `
Where-Object {$_.status -ne "Completed" -and $_.LastModifiedTime -gt (get-date).adddays(-$Lookback)} | `
Select-Object RunbookName, HybridWorker, Status, LastModifiedTime,JobId

## Create Email
$Header = @"
<style>
@charset "UTF-8";
table {font-family:Calibri;border-collapse:collapse;background-color: #f1f1f1}
td
{font-size:1em;border:1px solid #2191ca;padding:1px 5px 1px 5px;}
th
{font-size:1em;text-align:center;padding-top:4px;padding-bottom:4px;padding-right:4px;padding-left:4px;background-color:#2191ca ;color:#ffffff;}
name tr
</style> 
<h2 style="Calibri";> Attention: Problem with Automation Account Runbook(s) </h2>

"@

$EmailBody += $Header

if ($Jobs)
{
    $EmailBody += $Jobs | ConvertTo-HTML
    
    ## Send via SendGrid
    $params = @{
        ToEmailAddress = "xxx";
        FromEmailAddress = "xxx";
        Subject = "Attention: Problem with Automation Account Runbook(s)" + (Get-Date -DisplayHint Date);
        Body = $EmailBody;
    }

    Start-AzAutomationRunbook –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $resourceGroup –Parameters $params

}







