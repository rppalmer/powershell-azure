
$TenantID           = "xxx"    # Your tenant id (in Azure Portal, under Azure Active Directory -> Overview )
$GraphAppId         = "00000003-0000-0000-c000-000000000000"    # Microsoft Graph App Id (**DONT CHANGE**)
#$AADGraphAppId      = "00000002-0000-0000-c000-000000000000"    # Windows Azure Active Direcory App Id (**DONT CHANGE**)
#$EXOGraphAppId      = "00000002-0000-0ff1-ce00-000000000000"    # Office 365 Exchange Online App Id (**DONT CHANGE**)
$DisplayNameOfMSI   = "xxx"                        # Name of the managed identity

# Check the AAD/Microsoft Graph documentation for the permission you need for the operation
$GraphPermissions = @("Directory.ReadWrite.All")
#$AADPermissions = @("Application.Read.All")
#$EXOPermissions = @("Exchange.ManageAsApp")

Connect-AzureAD -TenantId $TenantID 

$MSI = (Get-AzureADServicePrincipal -Filter "displayName eq '$DisplayNameOfMSI'")
Write-Host "[*] Getting $MSI.Displayname"

#########################
### GRAPH PERMISSIONS ###
#########################

# Get Graph SP Object
Write-Host "[*] Getting Graph App Id..."
$GraphServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$GraphAppId'"

Foreach ($GraphPermission in $GraphPermissions)
{
    # Find matching app role in Graph object
    Write-Host "[*] Getting matching permission for $GraphPermission"    
    $AppRole = $GraphServicePrincipal.AppRoles | Where-Object {$_.Value -eq $GraphPermission -and $_.AllowedMemberTypes -contains "Application"}

    # Apply new role assignment
    Write-Host "[*] Setting Permission $GraphPermission"
    New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $GraphServicePrincipal.ObjectId -Id $AppRole.Id
}

#######################
### AAD PERMISSIONS ###
#######################

# Write-Host "[*] Getting AAD App Id..."
# $AADServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$AADGraphAppId'"

# Foreach ($AADPermission in $AADPermissions)
# {
#     # Find matching app role in AAD object
#     Write-Host "[*] Getting matching permission for $AADPermission"
#     $AppRole = $AADServicePrincipal.AppRoles | Where-Object {$_.Value -eq $AADPermission -and $_.AllowedMemberTypes -contains "Application"}

#     # Apply new role assignment
#     Write-Host "[*] Setting Permission $AADPermission"
#     New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $AADServicePrincipal.ObjectId -Id $AppRole.Id
# }

# Write-Host "[*] Done!"

##############################################
### OFFICE 365 EXCHANGE ONLINE PERMISSIONS ###
##############################################

# Write-Host "[*] EXO Graph App Id  ..."
# $EXOServicePrincipal = Get-AzureADServicePrincipal -Filter "appId eq '$EXOGraphAppId'"

# Foreach ($EXOPermission in $EXOPermissions)
# {
#     # Find matching app role in Graph object
#     Write-Host "[*] Getting matching permission for $EXOPermission"
#     $AppRole = $EXOServicePrincipal.AppRoles | Where-Object {$_.Value -eq $EXOPermissions -and $_.AllowedMemberTypes -contains "Application"}

#     # Apply new role assignment
#     Write-Host "[*] Setting Permission $EXOPermission"
#     New-AzureAdServiceAppRoleAssignment -ObjectId $MSI.ObjectId -PrincipalId $MSI.ObjectId -ResourceId $EXOServicePrincipal.ObjectId -Id $AppRole.Id
# }

# Write-Host "[*] Done!"
