param (
    [cmdletbinding()]
    [parameter(Mandatory=$True)]
    [string]$ToEmailAddress,
    [parameter(Mandatory=$False)]
    [string]$AdditionalRecipient1,
    [parameter(Mandatory=$False)]
    [string]$AdditionalRecipient2,
    [parameter(Mandatory=$True)]
    [string]$FromEmailAddress,
    [parameter(Mandatory=$True)]
    [string]$Subject,
    [parameter(Mandatory=$False)]
    [string]$Body,
    [parameter(Mandatory=$False)]
    [array]$Attachments
)

Import-Module Az.Accounts
Import-Module Az.Automation
Import-Module Az.KeyVault

# Connect with Managed Identity
Connect-AzAccount -Identity

Get-AzContext -Verbose

# If To: is populated, but no additional recipients
if ($ToEmailAddress -and !$AdditionalRecipient1 -and !$AdditionalRecipient2)
{
    $personalizations = @(
            @{
                to = @(
                        @{
                            email = $ToEmailAddress
                        }
                    )              
            }
            
        )      
# If To: and AddlRecipient1: is popualted, but AddlRecipient2 is not.
}elseif ($ToEmailAddress -and $AdditionalRecipient1 -and !$AdditionalRecipient2)
{
    $personalizations = @(
            @{
                to = @(
                        @{
                            email = $ToEmailAddress
                        },
                        @{
                            email = $AdditionalRecipient1
                        }
                    )              
            }
            
        )  
# If To: and AddlRecipient2: is popualted, but AddlRecipient1 is not.    
}elseif ($ToEmailAddress -and !$AdditionalRecipient1 -and $AdditionalRecipient2)
{
    $personalizations = @(
            @{
                to = @(
                        @{
                            email = $ToEmailAddress
                        },
                        @{
                            email = $AdditionalRecipient2
                        }
                    )              
            }
            
        )      
# If To: ,AddlRecipient1:, and AddlRecipient2 are all popualted
}elseif ($ToEmailAddress -and $AdditionalRecipient1 -and $AdditionalRecipient2)
{
    $personalizations = @(
            @{
                to = @(
                        @{
                            email = $ToEmailAddress
                        },
                        @{
                            email = $AdditionalRecipient1
                        },
                        @{
                            email = $AdditionalRecipient2
                        }
                    )              
            }
            
        )      
}


$SENDGRID_API_KEY = Get-AzKeyVaultSecret -VaultName "xxx" -Name "xxx" -AsPlainText
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer " + $SENDGRID_API_KEY)
$headers.Add("Content-Type", "application/json")

# Body with attachement for SendGrid
if (!$attachments)
{
    $SendGridBody = @{
        personalizations = $personalizations
        from = @{
                    email = $FromEmailAddress
        }
        subject = $Subject
        content = @(
            @{
                type = "text/html"
                value = $Body
            }
        ) 
    }
}else{
    $SendGridBody = @{
        personalizations = $personalizations      
        from = @{
                    email = $FromEmailAddress
        }
        subject = $Subject
        content = @(
            @{
                type = "text/html"
                value = $Body
            }
        ) 
        attachments = @(
                            $Attachments
                        )
    }
}

$BodyJson = $SendGridBody | ConvertTo-Json -Depth 4

$response = Invoke-RestMethod -Uri https://api.sendgrid.com/v3/mail/send -Method Post -Headers $headers -Body $bodyJson