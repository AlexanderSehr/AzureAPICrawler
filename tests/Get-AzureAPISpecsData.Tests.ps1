$testCases = @(
    @{
        ProviderNamespace   = 'Microsoft.Storage'
        ResourceType        = 'storageAccounts'
        ExpectedIdentifiers = @(
            'Microsoft.Storage/storageAccounts',
            'Microsoft.Storage/storageAccounts/blobServices',
            'Microsoft.Storage/storageAccounts/blobServices/containers',
            'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies',
            'Microsoft.Storage/storageAccounts/encryptionScopes',
            'Microsoft.Storage/storageAccounts/fileServices',
            'Microsoft.Storage/storageAccounts/fileServices/shares',
            'Microsoft.Storage/storageAccounts/inventoryPolicies',
            'Microsoft.Storage/storageAccounts/localUsers',
            'Microsoft.Storage/storageAccounts/managementPolicies',
            'Microsoft.Storage/storageAccounts/objectReplicationPolicies',
            'Microsoft.Storage/storageAccounts/privateEndpointConnections',
            'Microsoft.Storage/storageAccounts/queueServices',
            'Microsoft.Storage/storageAccounts/queueServices/queues',
            'Microsoft.Storage/storageAccounts/tableServices',
            'Microsoft.Storage/storageAccounts/tableServices/tables'
        )
        ExpectedParameters  = @(
            @{
                minLength = 3
                name      = "name"
                maxLength = 24
                required  = $true
                type      = "string"
                level     = 0
            },
            @{
                default       = ""
                name          = "type"
                description   = "The identity type."
                type          = "string"
                required      = $false
                level         = 1
                Parent        = "identity"
                allowedValues = @(
                    'None',
                    'SystemAssigned',
                    'UserAssigned',
                    'SystemAssigned,UserAssigned'
                )
            },
            @{
                Parent      = "properties"
                name        = "encryption"
                description = "The encryption settings on the storage account."
                type        = "object"
                level       = 1
                required    = $false
                default     = @{}
            }
        )
        IsSingleton         = $false
    },
    @{
        ProviderNamespace   = 'Microsoft.Storage'
        ResourceType        = 'storageAccounts/blobServices/containers'
        ExpectedIdentifiers = @(
            'Microsoft.Storage/storageAccounts/blobServices/containers',
            'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPolicies'
            'Microsoft.Storage/storageAccounts/blobServices/containers/immutabilityPoliciess'
        )
        ExpectedParameters  = @(
            @{
                minLength   = 3
                name        = "name"
                maxLength   = 63
                required    = $true
                type        = "string"
                level       = 0
                description = "The name of the blob container within the specified storage account. Blob container names must be between 3 and 63 characters in length and use numbers, lower-case letters and dash (-) only. Every dash (-) character must be immediately preceded and followed by a letter or number."
            },
            @{
                default       = ""
                name          = "publicAccess"
                description   = "Specifies whether data in the container may be accessed publicly and the level of access."
                type          = "string"
                required      = $false
                level         = 1
                Parent        = "properties"
                allowedValues = @(
                    "Container"
                    "Blob"
                    "None"
                )
            }
        )
        IsSingleton         = $false
    },
    @{
        ProviderNamespace   = 'Microsoft.Storage'
        ResourceType        = 'storageAccounts/blobServices'
        IsSingleton         = $true
    }
)

Describe "Test Provider Details" {

    Context "[<ProviderNamespace>/<ResourceType>]" -ForEach $testCases {

        BeforeAll {
            $foundData = Get-AzureAPISpecsData -FullResourceType "$ProviderNamespace/$ResourceType" -KeepArtifacts
            if (-not $foundData) {
                throw "Invocation failed for Resource Type [$ProviderNamespace/$ResourceType]"
            }
        }

        It 'Type found' {
            $foundData | Should -Not -BeNullOrEmpty
        }
        
        It "All expected identifiers found" {
            $missingIdentifiers = $expectedIdentifier | Where-Object { $_ -notin $foundData.Keys }
            $missingIdentifiers | Should -BeNullOrEmpty
        }

        It "Should be correctly identified as a singleton" {
            $foundData[("$ProviderNamespace/$ResourceType")].data.isSingleton | Should -Be $IsSingleton
        }

        It "should find parameters as expected" {
            $foundParameters =  $foundData[("$ProviderNamespace/$ResourceType")].data.parameters

            foreach($expectedParameter in $ExpectedParameters) {

                $matchingFoundParam = $foundParameters | Where-Object { 
                    $_.name -eq $expectedParameter.name -and 
                    $_.level -eq $expectedParameter.level -and
                    $_.parent -eq $expectedParameter.parent
                }
                $matchingFoundParam | Should -Not -BeNullOrEmpty -Because ('we should have found a parameter with name [{0}] in level [{1}]' -f $expectedParameter.name, $expectedParameter.level)

                $matchingFoundParam.type | Should -Be $expectedParameter.type
                $matchingFoundParam.minLength | Should -Be $expectedParameter.minLength
                $matchingFoundParam.maxLength | Should -Be $expectedParameter.maxLength
                $matchingFoundParam.required | Should -Be $expectedParameter.required
            }
        }        
    }
}
