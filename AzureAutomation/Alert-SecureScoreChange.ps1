
$automationAccount      = "xxx"                        # Azure Automation Account Name
$resourceGroup          = "xxx"                  # Azure Automation Account Resource Group Name
$WorkspaceId            = "xxx"    # Log Analytics Workspace Id for query
$TenantId               = "xxx"    # AAD Tenant ID
$Threshold              = 0.03                                      # Alert threshold


# Connect with Managed Identity
Connect-AzAccount -Identity

# Get Graph Token
$GraphURL = "https://graph.microsoft.com/" 
$Response = [System.Text.Encoding]::Default.GetString((Invoke-WebRequest -UseBasicParsing `
-Uri "$($env:IDENTITY_ENDPOINT)?resource=$GraphURL" -Method 'GET' -Headers `
@{'X-IDENTITY-HEADER' = "$env:IDENTITY_HEADER"; 'Metadata' = 'True'}).RawContentStream.ToArray()) | ConvertFrom-Json 
$graphToken = $Response.access_token 

$uri = 'https://graph.microsoft.com/v1.0/security/secureScores?$top=2'

$Header = @{
    'Content-Type'  = "application\json"
    'Authorization' = "BEARER $graphToken"
}

# set send email initially to false
$EmailAlert = $false

# Get 2 most recent secure scores
$SecureScores = Invoke-RestMethod -Headers $Header -Uri $Uri -UseBasicParsing -Method Get -ContentType "application/json"
$SecureScores

# Don't proceed unless the score is lower than previous day
if ($SecureScores.value[0].currentScore -lt $SecureScores.value[1].currentScore)
{
    
    # Get current and previous day score percentage
    $CurDayScore = [math]::Round($SecureScores.value.currentScore[0] / $SecureScores.value.maxScore[0],4)
    $PrevDayScore = [math]::Round($SecureScores.value.currentScore[1] / $SecureScores.value.maxScore[0],4)

    # Get Delta and alert if greater than threshold
    $Delta = $PrevDayScore - $CurDayScore
    if ($Delta -gt $Threshold)
    {
        # send alert
        $EmailAlert = $True

    }
}

# Send alert
if ($EmailAlert -eq $True)
{
    
$emailBody = @"
<th class="expander" style="word-wrap: break-word;-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;Margin: 0;text-align: left;font-size: 14px;line-height: 20px;visibility: hidden;width: 0;padding: 0">
</th>
</tr>
</tbody>
</table>
</th>
</tr>
</tbody>
</table>
</center>
</td>
</tr>
</tbody>
</table>
</td>
</tr>
</tbody>
</table>
<table role="presentation" align="center" class="container template-container section" style="border-spacing: 0;border-collapse: collapse;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;mso-table-lspace: -1pt;mso-table-rspace: -1pt;background: #ffffff;width: 640px;Margin: 0 auto;text-align: inherit">
<tbody>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<td style="word-wrap: break-word;-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;Margin: 0;text-align: left;font-size: 14px;line-height: 20px">
<table role="presentation" class="wrapper outer-wrapper" align="center" style="border-spacing: 0;border-collapse: collapse;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left;mso-table-lspace: -1pt;mso-table-rspace: -1pt;width: 100%">
<tbody>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<td class="wrapper-inner" style="word-wrap: break-word;-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;padding-right: 0;padding-left: 0;Margin: 0;text-align: left;font-size: 14px;line-height: 20px;padding-bottom: 12px;mso-padding-bottom-alt: 12px;padding-top: 6px;mso-padding-top-alt: 6px">
<center style="width: 100%;min-width: 640px">
<table role="presentation" align="center" class="row float-center" style="border-spacing: 0;border-collapse: collapse;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;mso-table-lspace: -1pt;mso-table-rspace: -1pt;padding: 0;width: 100%;position: relative;Margin: 0 auto;float: none;text-align: center;display: table">
<tbody>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<th class="small-12 large-12 columns first last" style="word-wrap: break-word;-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;text-align: left;font-size: 14px;line-height: 20px;Margin: 0 auto;width: 616px;padding-bottom: 12px;mso-padding-bottom-alt: 12px;padding-left: 24px;padding-right: 24px;padding-top: 6px;mso-padding-top-alt: 6px">
<table role="presentation" style="border-spacing: 0;border-collapse: collapse;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left;mso-table-lspace: -1pt;mso-table-rspace: -1pt;width: 100%">
<tbody>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<th style="word-wrap: break-word;-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;Margin: 0;text-align: left;font-size: 14px;line-height: 20px">
<h1 style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;Margin: 0;text-align: left;color: inherit;Margin-bottom: 16px;-webkit-hyphens: none;-moz-hyphens: none;-ms-hyphens: none;hyphens: none;letter-spacing: -.01em;font-family: Segoe UI Semibold, SegoeUISemibold, Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 600;font-size: 28px;line-height: 36px;mso-line-height-alt: 36px;word-wrap: normal;-webkit-text-size-adjust: none">
Secure Score Change Detected</h1>
<h3 style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;Margin: 0;text-align: left;color: inherit;Margin-bottom: 16px;font-family: Segoe UI Semibold, SegoeUISemibold, Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 600;font-size: 20px;line-height: 28px;mso-line-height-alt: 28px;word-wrap: normal;-webkit-text-size-adjust: none">
View details:</h3>
<table role="presentation" class="table-default table-heading-rows" style="border-spacing: 0;border-collapse: collapse;padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left;mso-table-lspace: -1pt;mso-table-rspace: -1pt;max-width: 592px;width: 100%">
<tbody>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<th style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;color: #11100f;Margin: 0;text-align: left;line-height: 20px;padding-left: 6px;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;font-size: 14px;padding-right: 12px;vertical-align: top;width: 1%;white-space: nowrap;word-wrap: initial;font-family: Segoe UI Semibold, SegoeUISemibold, Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 600;border-top: none">
Today's Score</th>
<td style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;Margin: 0;text-align: left;font-size: 14px;line-height: 20px;word-wrap: break-word;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;padding-right: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;padding-left: 12px;border-top: none">
$($SecureScores.value[0].currentScore) - $($CurDayScore.ToString("P"))</td>
</tr>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<th style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;color: #11100f;Margin: 0;text-align: left;line-height: 20px;padding-left: 6px;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;font-size: 14px;padding-right: 12px;vertical-align: top;width: 1%;white-space: nowrap;word-wrap: initial;font-family: Segoe UI Semibold, SegoeUISemibold, Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 600">
Yesterday's Score</th>
<td style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;Margin: 0;text-align: left;font-size: 14px;line-height: 20px;word-wrap: break-word;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;padding-right: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;padding-left: 12px">
$($SecureScores.value[1].currentScore) - $($PrevDayScore.ToString("P"))</td>
</tr>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<th style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;color: #11100f;Margin: 0;text-align: left;line-height: 20px;padding-left: 6px;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;font-size: 14px;padding-right: 12px;vertical-align: top;width: 1%;white-space: nowrap;word-wrap: initial;font-family: Segoe UI Semibold, SegoeUISemibold, Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 600">
Max Score</th>
<td style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;Margin: 0;text-align: left;font-size: 14px;line-height: 20px;word-wrap: break-word;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;padding-right: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;padding-left: 12px">
$($SecureScores.value.maxScore[0])</td>
</tr>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<th style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;color: #11100f;Margin: 0;text-align: left;line-height: 20px;padding-left: 6px;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;font-size: 14px;padding-right: 12px;vertical-align: top;width: 1%;white-space: nowrap;word-wrap: initial;font-family: Segoe UI Semibold, SegoeUISemibold, Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 600">
Threshold</th>
<td style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;Margin: 0;text-align: left;font-size: 14px;line-height: 20px;word-wrap: break-word;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;padding-right: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;padding-left: 12px">
3.00%</td>
</tr>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<th style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;color: #11100f;Margin: 0;text-align: left;line-height: 20px;padding-left: 6px;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;font-size: 14px;padding-right: 12px;vertical-align: top;width: 1%;white-space: nowrap;word-wrap: initial;font-family: Segoe UI Semibold, SegoeUISemibold, Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 600">
Delta</th>
<td style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;Margin: 0;text-align: left;font-size: 14px;line-height: 20px;word-wrap: break-word;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;padding-right: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;padding-left: 12px">
$Delta</td>
</tr>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
<th style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;color: #11100f;Margin: 0;text-align: left;line-height: 20px;padding-left: 6px;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;font-size: 14px;padding-right: 12px;vertical-align: top;width: 1%;white-space: nowrap;word-wrap: initial;font-family: Segoe UI Semibold, SegoeUISemibold, Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 600">
Secure Score Dashboard</th>
<td style="-webkit-hyphens: auto;-moz-hyphens: auto;hyphens: auto;border-collapse: collapse;vertical-align: top;color: #11100f;font-family: Segoe UI, SegoeUI, Roboto, &quot;Helvetica Neue&quot;, Arial, sans-serif;font-weight: 400;Margin: 0;text-align: left;font-size: 14px;line-height: 20px;word-wrap: break-word;mso-padding-left-alt: 6px;padding-top: 6px;mso-padding-top-alt: 6px;padding-right: 6px;mso-padding-right-alt: 6px;padding-bottom: 6px;mso-padding-bottom-alt: 6px;border-top: solid 1px #dedede;padding-left: 12px">
<a href="https://security.microsoft.com/securescore?viewid=overview&tid=483fadee-89c9-4311-912d-37212c6f09aa">https://security.microsoft.com/securescore?viewid=overview&tid=483fadee-89c9-4311-912d-37212c6f09aa</a></td>
</tr>
<tr style="padding-top: 0;padding-right: 0;padding-bottom: 0;padding-left: 0;vertical-align: top;text-align: left">
"@

    # Send via SendGrid
    $params = @{
        ToEmailAddress = "xxx";
        FromEmailAddress = "xxx";
        Subject = "Secure Score Alert - " + (Get-Date -DisplayHint Date);
        Body = $emailBody
    }

    # Set Context of Runbook and call Set-SendGridMessage runbook and pass params for email
    $AzureContext = Set-AzContext -SubscriptionId "xxx"
    Start-AzAutomationRunbook  –Name 'Set-SendGridMessagev2' -AutomationAccountName $automationAccount -ResourceGroupName $resourceGroup –Parameters $params

}