param (
    [Parameter(Mandatory = $true)]
    [string] $ResourceModulesFilePath
)

$templateFilePaths = (Get-ChildItem -Path (Join-Path $ResourceModulesFilePath 'modules') -Filter 'deploy.bicep' -Recurse).FullName

$testCases = [System.Collections.ArrayList]@()
foreach ($templateFilePath in $templateFilePaths) {
    $fileContent = Get-Content -Path $templateFilePath

    foreach ($line in $fileContent) {

        if ($line -match "^resource \w+ '(.+)@(.+)' (existing )?= .+$") {
            $resourceIdentifier = $Matches[1]
            $apiVersion = $Matches[2]
            
            $providerNamespace = ($resourceIdentifier -split '\/')[0]
            $resourceType = $resourceIdentifier -replace "$providerNamespace\/"

            $alreadyCovered = $testCases | Where-Object {
                $_.providerNamespace -eq $providerNamespace -and
                $_.resourceType -eq $resourceType -and
                $_.apiVersion -eq $apiVersion
            }

            if ($alreadyCovered) {
                continue
            }

            $testCases += @{
                providerNamespace    = $providerNamespace
                resourceType         = $resourceType
                apiVersion           = $apiVersion
            }
        }
    }
}

BeforeAll {
    $availableAPIVersions = Get-AzureAPISpecsVersionList -IncludePreview -Verbose -KeepArtifacts -IncludeExternalSources | ConvertTo-Json | ConvertFrom-Json
    if (-not $availableAPIVersions) {
        throw "Fetch of API versions failed"
    }
}

Describe "Test API version availablity" {

    It "Resource Type [<providerNamespace>/<resourceType>] should be found with API Version [<apiVersion>]" -ForEach $testCases {

        # Provider Namespace test
        ($availableAPIVersions | Get-Member -Type NoteProperty).Name  | Should -Contain $providerNamespace
        
        # Resource Type test
        ($availableAPIVersions.$providerNamespace | Get-Member -Type NoteProperty).Name  | Should -Contain $resourceType

        # API version test
        $availableAPIVersions.$providerNamespace.$resourceType | Should -Contain $apiVersion
    }
}

