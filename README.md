# Azure API Crawler

This module provides you with the ability to fetch data from the API specs.

<details>

<summary><code>Get-AzureAPISpecsData</code></summary>

Use this utility to get detailed information of a provided ProviderNamespace-ResourceType combination such as  the available properties.

### _Navigation_

- [Usage](#get-AzureAPIspecsdata-usage)
- [In-scope](#get-AzureAPIspecsdata-in-scope)
- [Known issues](#get-AzureAPIspecsdata-known-issues)

---

> Note: This utility is related to the [CARML](https://aka.ms/CARML) repository. Hence this may returns additional information you may not find useful (for example, the file content for a module's RBAC deployment).

## `Get-AzureAPISpecsData`: Usage
- Import the module using the command `Import-Module './utilities/tools/AzureAPICrawler/AzureAPICrawler.psm1' -Force -Verbose`
- Invoke its primary function using the command `Get-AzureAPISpecsData -ProviderNamespace '<ProviderNamespace>' -ResourceType '<ResourceType>' -Verbose -KeepArtifacts`
- For repeated runs it is recommended to append the `-KeepArtifacts` parameter as the function will otherwise repeatably download & eventually delete the required documentation
- Process the output
  At the time of this writing, the output structure is not yet decided. To this end, the function will return a flat list of all parameters with all their data. The following examples may give you some inspiration what you can do with that output.

### Example 1  

Get the Storage Account resource data (and the one of all its child-resources)

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts' -Verbose -KeepArtifacts

# The object looks somewhat like:
# Name                           Value
# ----                           -----
# data                           {outputs, parameters, resources, variables…}
# identifier                     Microsoft.Storage/storageAccounts
# metadata                       {parentUrlPath, urlPath}
#
# data                           {outputs, parameters, resources, variables…}
# identifier                     Microsoft.Storage/storageAccounts/localUsers
# metadata                       {parentUrlPath, urlPath}
```

### Example 2

Filter the list down to only the Storage Account itself

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts' -Verbose -KeepArtifacts
$storageAccountResource = $out | Where-Object { $_.identifier -eq 'Microsoft.Storage/storageAccounts' }
```

### Example 3

Print a simple outline similar to the Azure Resource reference:

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts' -Verbose -KeepArtifacts
$storageAccountResource = $out | Where-Object { $_.identifier -eq 'Microsoft.Storage/storageAccounts' }
$storageAccountResource.data.parameters | ForEach-Object { '{0}{1}:{2}' -f ('  ' * $_.level), $_.name, $_.type  } 

# Returns:
# --------
# name:string
# extendedLocation:object
#   type:string
#   name:string
# identity:object
#   type:string
#   userAssignedIdentities:object
# kind:string
# properties:object
#   keyPolicy:object
#   (...)
```

### Example 4

Filter parameters down to those containing the keyword 'network' and format the result as JSON.

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts' -Verbose -KeepArtifacts
$storageAccountResource = $out | Where-Object { $_.identifier -eq 'Microsoft.Storage/storageAccounts' }
$storageAccountResource.data.parameters | Where-Object { $_.description -like "*network*" } | ConvertTo-Json

# Returns:
# --------
# [
#   {
#     "level": 1,
#     "type": "string",
#     "allowedValues": [
#       "Enabled",
#       "Disabled"
#     ],
#     "name": "publicNetworkAccess",
#     "required": false,
#     "description": "Allow or disallow public network access to Storage Account. Value is optional but if passed in, must be 'Enabled' or 'Disabled'.",
#     "Parent": "properties"
#   },
#   {
#     "level": 1,
#     "type": "object",
#     "name": "routingPreference",
#     "required": false,
#     "description": "Routing preference defines the type of network, either microsoft or internet routing to be used to deliver the user data, the default option is microsoft routing",
#     "Parent": "properties"
#   },
#   (...)
# ]
```

### Example 5

Use the Grid-View to enable dynamic UI processing using a table format

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts' -Verbose -KeepArtifacts
$storageAccountResource = $out | Where-Object { $_.identifier -eq 'Microsoft.Storage/storageAccounts' }
$storageAccountResource.data.parameters | Where-Object { 
  $_.type -notin @('object','array') 
} | ForEach-Object { 
  [PSCustomObject]@{ 
    Name        = $_.name
    Description = $_.description  
  }
} | Out-GridView
```

<img alt="Grid View" src="./src/GridViewFilter.jpg" />


### Example 6

Get data for a specific child-resource type

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts/blobServices/containers' -Verbose -KeepArtifacts
```

### Example 7

Check if a specific resource type supports Locks

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts/blobServices/containers' -Verbose -KeepArtifacts
$out | Foreach-Object { 
  [PSCustomObject]@{
    Name         = $_.identifier
    'Supports Lock' = $_.data.additionalParameters.name -contains 'lock' 
  }
} | Sort-Object -Property 'Name'

# Returns:
# --------
# Name                                                                           Supports Lock
# ----                                                                           -------------
# Microsoft.Storage/storageAccounts/blobServices/containers                              False
# Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies         False
```

### Example 8

Check if a specific resource type supports Private Endpoints

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts/blobServices/containers' -Verbose -KeepArtifacts
$out | Foreach-Object { 
  [PSCustomObject]@{
    Name = $_.identifier
    'Supports Private Endpoints' = $_.data.additionalParameters.name -contains 'privateEndpoints' 
  }
} | Sort-Object -Property 'Name'

# Returns:
# --------
# Name                                                                           Supports Private Endpoints
# ----                                                                           --------------------------
# Microsoft.Storage/storageAccounts/blobServices/containers                                           False
# Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies                      False
```

### Example 9

Check if a specific resource type supports Diagnostic Settings

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts/blobServices/containers' -Verbose -KeepArtifacts
$out | Foreach-Object { 
  [PSCustomObject]@{
    Name = $_.identifier
    'Supports Diagnostic Settings' = $_.data.additionalParameters.name -contains 'diagnosticWorkspaceId' 
  }
} | Sort-Object -Property 'Name'

# Returns:
# --------
# Name                                                                           Supports Diagnostic Settings
# ----                                                                           ----------------------------
# Microsoft.Storage/storageAccounts/blobServices/containers                                             False
# Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies                        False
```

### Example 10

Check if a specific resource type supports RBAC

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts/blobServices/containers' -Verbose -KeepArtifacts
$out | Foreach-Object { 
  [PSCustomObject]@{
    Name = $_.identifier
    'Supports Role Assignments' = $_.data.additionalParameters.name -contains 'roleAssignments' 
  }
} | Sort-Object -Property 'Name'

# Returns:
# --------
# Name                                                                           Supports Role Assignments
# ----                                                                           -------------------------
# Microsoft.Storage/storageAccounts/blobServices/containers                                           True
# Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies                      True
```

### Example 11

Get the RBAC roles that apply to a given Resource Type (if any)

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts/blobServices/containers' -Verbose -KeepArtifacts
(($out | Where-Object { 
  $_.identifier -eq 'Microsoft.Storage/storageAccounts/blobServices/containers' 
}).data.additionalFiles | Where-Object { 
  $_.type -eq 'roleAssignments' 
}).onlyRoleDefinitionNames

# Returns:
# --------
# Avere Contributor
# Avere Contributor
# Avere Operator
# Avere Operator
# Backup Contributor
# Backup Operator
# Contributor
# Desktop Virtualization Virtual Machine Contributor
``` 

### Example 12

Get an overview of which resource type supports which extension resource (e.g. Private Endpoints) 

```PowerShell
$out = Get-AzureAPISpecsData -FullResourceType 'Microsoft.Storage/storageAccounts' -Verbose -KeepArtifacts
$out | Foreach-Object { 
  [PSCustomObject]@{
    Name = $_.identifier
    'RBAC' = $_.data.additionalParameters.name -contains 'roleAssignments' 
    'Diagnostic Settings' = $_.data.additionalParameters.name -contains 'diagnosticWorkspaceId' 
    'Private Endpoints' = $_.data.additionalParameters.name -contains 'privateEndpoints' 
    'Lock' = $_.data.additionalParameters.name -contains 'lock' 
  }
} | Sort-Object -Property 'Name' | Format-Table

# Returns:
# --------
# Name                                                                            RBAC Diagnostic Settings Private Endpoints Locks
# ----                                                                            ---- ------------------- ----------------- -----
# Microsoft.Storage/storageAccounts                                               True                True              True  True
# Microsoft.Storage/storageAccounts/blobServices                                  True                True             False False
# Microsoft.Storage/storageAccounts/blobServices/containers                       True               False             False False
# Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies False               False             False False
# Microsoft.Storage/storageAccounts/encryptionScopes                             False               False              True False
# Microsoft.Storage/storageAccounts/fileServices                                 False                True             False False
# Microsoft.Storage/storageAccounts/fileServices/shares                          False               False             False False
# Microsoft.Storage/storageAccounts/inventoryPolicies                            False               False              True False
# Microsoft.Storage/storageAccounts/localUsers                                   False               False              True False
# Microsoft.Storage/storageAccounts/managementPolicies                           False               False              True False
# Microsoft.Storage/storageAccounts/objectReplicationPolicies                     True               False              True False
# Microsoft.Storage/storageAccounts/privateEndpointConnections                   False               False              True False
# Microsoft.Storage/storageAccounts/queueServices                                 True                True             False False
# Microsoft.Storage/storageAccounts/queueServices/queues                          True               False             False False
# Microsoft.Storage/storageAccounts/tableServices                                 True                True             False False
# Microsoft.Storage/storageAccounts/tableServices/tables                          True               False             False False
```

## `Get-AzureAPISpecsData`: In scope

- Fetch data for the resource type with parameters
- Fetch data for child resources
- Extension resources like RBAC, Private Endpoints, etc.

## `Get-AzureAPISpecsData`: Known issues

### Diagnostic Settings
The data source which is the basis for the Diagnostic Logs & Metrics is not 100% reliable

### Locks
The data source for Locks is not 100% reliable. Currently it is assumed that all top-level resources besides those in the Authorization Namespace support locks

### RBAC
The logic to determine if a resource supports RBAC also includes resources that 'could' have roles (as per their resource type) but actually don't support them (e.g., `Microsoft.Storage/storageAccounts/blobServices`).

</details>


<details>
<summary><code>Get-AzureAPISpecsVersionList</code></summary>

Use this utility to get an overview of all available API versions for any Provider specified in the [azure-rest-api-specs](https://github.com/Azure/azure-rest-api-specs) repository.

### _Navigation_

- [Usage](#get-azureapispecsversionlist-usage)
- [In-scope](#get-azureapispecsversionlist-in-scope)
- [Known issues](#get-azureapispecsversionlist-known-issues)

---

## `Get-AzureAPISpecsVersionList`: Usage

- Import the module using the command `Import-Module './utilities/tools/AzureAPICrawler/AzureAPICrawler.psm1' -Force -Verbose`
- Invoke its primary function using the command `Get-AzureAPISpecsVersionList -Verbose -KeepArtifacts`
- For repeated runs it is recommended to append the `-KeepArtifacts` parameter as the function will otherwise repeatably download & eventually delete the required documentation
- Process the output

### Example 1  

Get the Storage Account resource data (and the one of all its child-resources)

```PowerShell
$out = Get-AzureApiSpecsVersionList -KeepArtifacts -Verbose -IncludePreview | ConvertTo-Json

# The object looks somewhat like:
# {
#     "Microsoft.AAD": {
#         "domainServices": [
#             "2017-01-01",
#             "2017-06-01",
#             "2020-01-01",
#             "2021-03-01",
#             "2021-05-01",
#             "2022-09-01"
#         ],
#         "domainServices/ouContainer": [
#             "2017-06-01",
#             "2020-01-01",
#             "2021-03-01",
#             "2021-05-01",
#             "2022-09-01"
#         ]
#     },
#     "microsoft.aadiam": {
#         "azureADMetrics": [
#             "2020-07-01-preview"
#         ]
#     },
#     (..)
# }
```

## `Get-AzureAPISpecsVersionList`: In scope

- Fetch all API versions available for all Providers in the [azure-rest-api-specs](https://github.com/Azure/azure-rest-api-specs) repository.
- Filter optionally by preview version

## `Get-AzureAPISpecsVersionList`: Known issues

_None (yet)_

</details>