$testCases = @(
    @{
        ProviderNamespace = 'Microsoft.Storage'
        ResourceType = 'storageAccounts'
    }
    @{
        ProviderNamespace = 'Microsoft.Storage'
        ResourceType = 'storageAccounts/blobServices/containers'
    }
)

Describe "Test Provider Details" {

    It "Resource Type [<ProviderNamespace>/<ResourceType>] found" -TestCases $testCases {

        param(
            [string] $ProviderNamespace,
            [string]  $ResourceType
        )

        $res = Get-AzureAPISpecsData -FullResourceType "$ProviderNamespace/$ResourceType" -Verbose -KeepArtifacts

        $res | Should -Not -BeNullOrEmpty
    }
}
