# REST to CARML

This module provides you with the ability to fetch data for the API specs by providing it with the desired Provider-Namespace / Resource-Type combination.

> Note: As this utility is strongly tight to the REST2CARML workstream of the [CARML](https://aka.ms/CARML) repository, the utility returns additional information you may not find useful (for example, the file content for a module's RBAC deployment).

### _Navigation_

- [Usage](#usage)
- [In-scope](#in-scope)
- [Out-of-scope](#out-of-scope)

---

## Usage
- Import the module using the command `Import-Module './utilities/tools/AzureApiCrawler/AzureApiCrawler.psm1' -Force -Verbose`
- Invoke its primary function using the command `Get-AzureApiSpecsData -ProviderNamespace '<ProviderNamespace>' -ResourceType '<ResourceType>' -Verbose -KeepArtifacts`
- For repeated runs it is recommended to append the `-KeepArtifacts` parameter as the function will otherwise repeatably download & eventually delete the required documentation
- Process the output
  At the time of this writing, the output structure is not yet decided. To this end, the function will return a flat list of all parameters with all their data. The following examples may give you some inspiration what you can do with that output:
  ```PowerShell
  # Get the Storage Account resource data (and the one of all its child-resources)
  $out = Get-AzureApiSpecsData -ProviderNamespace 'Microsoft.Storage' -ResourceType 'storageAccounts' -Verbose -KeepArtifacts

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

  # Filter the list down to only the Storage Account itself
  $storageAccountResource = $out | Where-Object { $_.identifier -eq 'Microsoft.Storage/storageAccounts' }

  # Print a simple outline similar to the Azure Resource reference:
  $storageAccountResource.data.parameters | ForEach-Object { '{0}{1}:{2}' -f ('  ' * $_.level), $_.name, $_.type  } 

  # Filter parameters down to those containing the keyword 'network' 
  $storageAccountResource.data.parameters | Where-Object { $_.description -like "*network*" } | ConvertTo-Json

  # Use the Grid-View to enable dynamic UI processing using a table format
  $storageAccountResource.data.parameters | Where-Object { $_.type -notin @('object','array') } | ForEach-Object { [PSCustomObject]@{ Name = $_.name; Description = $_.description  }  } | Out-GridView

  # Get data for a specific child-resource type
  $out = Get-AzureApiSpecsData -ProviderNamespace 'Microsoft.Storage' -ResourceType 'storageAccounts/blobServices/containers' -Verbose -KeepArtifacts

  # Additional evaluation
  ## Supports Locks
  $out | Foreach-Object { [PSCustomObject]@{name = $_.identifier; supportsLock = $_.data.additionalParameters.name -contains 'lock' }} | Sort-Object -Property 'Name'

  ## Supports Private Endpoints
  $out | Foreach-Object { [PSCustomObject]@{name = $_.identifier; supportsLock = $_.data.additionalParameters.name -contains 'privateEndpoints' }} | Sort-Object -Property 'Name'
  
  ## Supports Diagnostic Settings
  $out | Foreach-Object { [PSCustomObject]@{name = $_.identifier; supportsLock = $_.data.additionalParameters.name -contains 'diagnosticWorkspaceId' }} | Sort-Object -Property 'Name'

  ## Supports RBAC
  $out | Foreach-Object { [PSCustomObject]@{name = $_.identifier; supportsLock = $_.data.additionalParameters.name -contains 'roleAssignments' }} | Sort-Object -Property 'Name'
  
  ## Supported RBAC Roles
  (($out | Where-Object { $_.identifier -eq 'Microsoft.Storage/storageAccounts/blobServices/containers' }).data.additionalFiles | Where-Object { $_.type -eq 'roleAssignments' }).onlyRoleDefinitionNames
  ```
  <img alt="Grid View" src="./src/GridViewFilter.jpg" />
 

# In scope

- Fetch data for the resource type with parameters
- Fetch data for child resources
- Extension resources like RBAC, Private Endpoints, etc.?
  > Note: The data source for Diagnostic Locks & Metrics is not 100% reliable
  > Note: The data source for Locks is not 100% reliable. Currently it is assumed that all top-level resources besides those in the Authorization Namespace support locks