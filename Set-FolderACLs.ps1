$CISPath = "C:\Temp\CISv4"

if (Test-Path $CISPath){Remove-Item $CISPath}

New-Item $CISPath -ItemType Directory

# Get folder ACL
$ACL = Get-Acl -Path $CISPath

# Remove Inheritance
$ACL.SetAccessRuleProtection($True,$True) # Remove inheritance, keep ACLs  

# Update ACL
Set-Acl -path $CISPath -AclObject $ACL

# Get new ACL
$ACL = Get-Acl -Path $CISPath

# Remove ACEs for authenticated users and builtin\users
Foreach ($ACE in ($ACL.access | Where-Object {($_.IdentityReference -contains 'NT AUTHORITY\Authenticated Users' -or $_.IdentityReference -contains 'BUILTIN\Users')}))
{

    $ACL.RemoveAccessRule($ACE)
}

# Update ACL
Set-Acl -path $CISPath -AclObject $ACL
