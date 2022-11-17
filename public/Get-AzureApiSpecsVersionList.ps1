<#
.SYNOPSIS
Get an overview of all API Versions for any existing ProviderNamespace/ResourceType combination

.DESCRIPTION
Get an overview of all API Versions for any existing ProviderNamespace/ResourceType combination

.PARAMETER IncludePreview
Optional. Provide if preview versions should be included

.PARAMETER KeepArtifacts
Optional. Provide if any downloaded data should not be removed after the function ran. This is useful to speed up subsequent runs.

.EXAMPLE
Get-AzureApiSpecsVersionList 

Returns an object like:
{
    "Microsoft.AAD": {
        "domainServices": [
            "2017-01-01",
            "2017-06-01",
            "2020-01-01",
            "2021-03-01",
            "2021-05-01",
            "2022-09-01"
        ],
        "domainServices/ouContainer": [
            "2017-06-01",
            "2020-01-01",
            "2021-03-01",
            "2021-05-01",
            "2022-09-01"
        ]
    },
    (...)
}

#>
function Get-AzureApiSpecsVersionList {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch] $IncludePreview,

        [Parameter(Mandatory = $false)]
        [switch] $KeepArtifacts
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
    }

    process {

        #########################################
        ##   Temp Clone API Specs Repository   ##
        #########################################
        $repoUrl = $script:CONFIG.url_CloneRESTAPISpecRepository
        $repoName = Split-Path $repoUrl -LeafBase
        $specificationPath = Join-Path (Join-Path $script:temp $repoName) 'specification'

        Copy-CustomRepository -RepoUrl $repoUrl -RepoName $repoName

        try {
            ##############################
            ##   Collect API Versions   ##
            ##############################
            $relevantFolderList = Get-FolderList -RootFolder $specificationPath

            $filePaths = $relevantFolderList | Foreach-Object { (Get-ChildItem -Path $_ -Recurse -Filter '*.json').FullName } | Where-Object { 
                (Split-Path $_ -Leaf) -notin @('common.json', 'privatelinks.json') -and
                ($_ -replace '\\', '/') -notlike "*/examples/*"
            }

            if (-not $IncludePreview) {
                $beforeCount = $filePaths.Count
                $filePaths = $filePaths | Where-Object { ($_ -replace '\\', '/') -notlike "*/preview/*" }
                Write-Verbose ("Filtered [{0}] files for preview versions out" -f ($beforeCount - $filePaths.Count))
            }

            Write-Verbose ("Found [{0}] files to analyze" -f $filePaths.Count)

            $resultSet = @{}
            for ($fileIndex = 0; $fileIndex -lt $filePaths.Count; $fileIndex++) {
                $filePath = $filePaths[$fileIndex]

                $apiVersion = Split-Path (Split-Path $filePath -Parent) -Leaf

                $pathData = (Get-Content $filePath -Raw | ConvertFrom-Json -AsHashtable).paths

                if (-not $pathData) {
                    continue
                }

                # Collect all URL paths that
                # - contain a 'PUT' - which means you can create the resource
                # - end with a variable name {...} or 'default'
                # - contain the 'Microsoft.' provider, or equals any of the exceptions like ResourceGroup & ResourceTags
                $relevantPaths = $pathData.Keys | Where-Object { 
                    $pathData[$_].Keys -contains 'put' -and 
                    $_ -match "\w+}$|default$" -and 
                    ($_ -like "*Microsoft.*" -or $_ -in @(
                        '/subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}', # Special case: Resource Group
                        '/{scope}/providers/Microsoft.Resources/tags/default' # Special case: Tags
                    )) 
                }

                if (-not $relevantPaths) {
                    continue
                }

                foreach ($relevantPath in $relevantPaths) {

                    if ($relevantPath -eq '/subscriptions/{subscriptionId}/resourcegroups/{resourceGroupName}') {
                        # Special case: Resource Group
                        $providerNamespace = 'Microsoft.Resources'
                        $resourceType = 'resourceGroups'
                    }
                    else {
                        $identifierElem = ($relevantPath -split '\/providers\/')[-1] -split '\/'
                        $providerNamespace = $identifierElem[0] # E.g. Microsoft.Storage
                    
                        # Add the remaining elements (every 2nd as everything in between represents a 'name')
                        $remainingRelevantElem = $identifierElem[1..($identifierElem.Count)]
                        $resourceType = ''
                        for ($index = 0; $index -lt $remainingRelevantElem.Count; $index++) {
                            if ($index % 2 -eq 0) {
                                $resourceType += ('/{0}' -f $remainingRelevantElem[$index])
                            }
                        }
                        $resourceType = $resourceType.TrimStart('/')
                    }

                    if ($resultSet.Keys -notcontains $providerNamespace) {
                        $resultSet[$providerNamespace] = @{}
                    }
                    
                    if ($resultSet[$providerNamespace].Keys -notcontains $resourceType) {
                        $resultSet[$providerNamespace][$resourceType] = @()
                    }

                    $apiVersionList = (@() + $resultSet[$providerNamespace][$resourceType] + $apiVersion) | Sort-Object -Unique
                    $resultSet[$providerNamespace][$resourceType] = $apiVersionList -is [array] ? $apiVersionList : @($apiVersion)
                }

                $percentageComplete = [System.Math]::Floor(($fileIndex / $filePaths.Count) * 100)
                Write-Progress -Activity "Analyzing in progress" -Status ("[{0}/{1}] or {2}% files processed" -f $fileIndex, $filePaths.count, $percentageComplete) -PercentComplete $percentageComplete
            }

            # Order result
            $orderedResultSet = [ordered]@{}
            foreach ($providerNamespace in ($resultSet.Keys | Sort-Object)) {
                
                if ($orderedResultSet.Keys -notcontains $providerNamespace) {
                    $orderedResultSet[$providerNamespace] = [ordered]@{}
                }
                
                foreach ($resourceType in ($resultSet[$providerNamespace].Keys | Sort-Object)) {
                    $orderedResultSet[$providerNamespace][$resourceType] = $resultSet[$providerNamespace][$resourceType]
                }
            }

            $orderedResultSet
        }
        catch {
            throw ($_, $_.ScriptStackTrace)
        }
        finally {
            ##########################
            ##   Remove Artifacts   ##
            ##########################
            if (-not $KeepArtifacts) {
                Write-Verbose ('Deleting temp folder [{0}]' -f $script:temp)
                $null = Remove-Item $script:temp -Recurse -Force
            }
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
