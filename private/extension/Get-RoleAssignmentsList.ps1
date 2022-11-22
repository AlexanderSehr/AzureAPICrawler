<#
.SYNOPSIS
Fetch all available Role Definitions for the given ProviderNamespace

.DESCRIPTION
Fetch all available Role Definitions for the given ProviderNamespace
Leverges Microsoft Docs's [https://learn.microsoft.com/en-us/powershell/module/az.resources/get-azroledefinition?view=azps-8.3.0] to fetch the data

.PARAMETER ProviderNamespace
Mandatory. The Provider Namespace to fetch the role definitions for

.PARAMETER ResourceType
Mandatory. The ResourceType to fetch the role definitions for

.PARAMETER IncludeCustomRoles
Optional. Whether to include custom roles or not

.EXAMPLE
Get-RoleAssignmentsList -ProviderNamespace 'Microsoft.KeyVault' -ResourceType 'vaults'

Fetch all available Role Definitions for ProviderNamespace [Microsoft.KeyVault/vaults], excluding custom roles.

Example output:
# Name                                               Id
# ----                                               --
# Avere Contributor                                  4f8fab4f-1852-4a58-a46a-8eaf358af14a
# Avere Operator                                     c025889f-8102-4ebf-b32c-fc0c6f0c6bd9
# Backup Contributor                                 5e467623-bb1f-42f4-a55d-6e525e11384b
#>
function Get-RoleAssignmentsList {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string] $ProviderNamespace,

        [Parameter(Mandatory = $false)]
        [string] $ResourceType,

        [Parameter(Mandatory = $false)]
        [switch] $IncludeCustomRoles
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
    }

    process {

        #################
        ##   Get Roles ##
        #################
        $roleDefinitions = Get-DataUsingCache -Key 'roleDefinitions' -ScriptBlock { Get-AzRoleDefinition }

        # Filter Custom Roles
        if (-not $IncludeCustomRoles) {
            $roleDefinitions = $roleDefinitions | Where-Object { -not $_.IsCustom }
        }

        $relevantRoles = [System.Collections.ArrayList]@()

        if (($roleDefinitions | Where-Object { $_.Actions -like "$ProviderNamespace/$ResourceType/*" -or $_.DataActions -like "$ProviderNamespace/$ResourceType/*" }).Count -eq 0) {
            # Pressumably, no roles are supported for this resource as no roles with its scope exist
            return @()
        }

        # Filter Action based
        $relevantRoles += $roleDefinitions | Where-Object {
            $_.Actions -like "$ProviderNamespace/$ResourceType/*" -or
            $_.Actions -like "$ProviderNamespace/`**" -or
            $_.Actions -like '`**'
        }

        # Filter Data Action based
        $relevantRoles += $roleDefinitions | Where-Object {
            $_.DataActions -like "$ProviderNamespace/$ResourceType/*" -or
            $_.DataActions -like "$ProviderNamespace/`**" -or
            $_.DataActions -like '`**'
        }

        return ($relevantRoles | Sort-Object -Property 'Name' -Unique | ForEach-Object { 
                @{
                    Name = $_.name
                    Id   = $_.id
                }
            })
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
