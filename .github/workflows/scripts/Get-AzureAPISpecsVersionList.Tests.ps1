param (
    [Parameter(Mandatory = $true)]
    [string] $SpecsFilePath,

    [Parameter(Mandatory = $true)]
    [string] $ResourceModulesFilePath
)

$templateFilePaths = (Get-ChildItem -Path (Join-Path $ResourceModulesFilePath 'modules') -Filter 'deploy.bicep' -Recurse).FullName
$availableAPIVersions = Get-Content -Path $SpecsFilePath -Raw | ConvertFrom-Json -Depth 10

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
                availableAPIVersions = $availableAPIVersions
            }
        }
    }
}

Describe "Test API version availablity" {

    It "Resource Type [<providerNamespace>/<resourceType>] was found with API Version [<apiVersion>]" -TestCases $testCases {

        param(
            [string] $providerNamespace,
            [string]  $resourceType,
            [string]  $apiVersion,
            [PSCustomObject] $availableAPIVersions
        )

        # Provider Namespace test
        ($availableAPIVersions | Get-Member -Type NoteProperty).Name  | Should -Contain $providerNamespace
        
        # Resource Type test
        ($availableAPIVersions.$providerNamespace | Get-Member -Type NoteProperty).Name  | Should -Contain $resourceType

        # API version test
        $availableAPIVersions.$providerNamespace.$resourceType | Should -Contain $apiVersion
    }
}

