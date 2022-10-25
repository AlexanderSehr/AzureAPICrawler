<#
.SYNOPSIS
Get module configuration data based on the latest API information available

.DESCRIPTION
Get module configuration data based on the latest API information available. If you want to use a nested resource type, just concatinate the identifiers like 'storageAccounts/blobServices/containers'

.PARAMETER ProviderNamespace
Mandatory. The provider namespace to query the data for

.PARAMETER ResourceType
Mandatory. The resource type to query the data for

.PARAMETER ExcludeChildren
Optional. Don't include child resource types in the result

.PARAMETER IncludePreview
Optional. Include preview API versions

.PARAMETER KeepArtifacts
Optional. Skip the removal of downloaded/cloned artifacts (e.g. the API-Specs repository). Useful if you want to run the function multiple times in a row.

.EXAMPLE
Get-AzureApiSpecsData -ProviderNamespace 'Microsoft.Keyvault' -ResourceType 'vaults'

Get the data for [Microsoft.Keyvault/vaults]

.EXAMPLE
Get-AzureApiSpecsData -ProviderNamespace 'Microsoft.AVS' -ResourceType 'privateClouds' -Verbose -KeepArtifacts

Get the data for [Microsoft.AVS/privateClouds] and do not delete any downloaded/cloned artifact.

.EXAMPLE
Get-AzureApiSpecsData -ProviderNamespace 'Microsoft.Storage' -ResourceType 'storageAccounts/blobServices/containers' -Verbose -KeepArtifacts

Get the data for [Microsoft.Storage/storageAccounts/blobServices/containers] and do not delete any downloaded/cloned artifact.
#>
function Get-AzureApiSpecsData {

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ProviderNamespace,

        [Parameter(Mandatory = $true)]
        [string] $ResourceType,

        [Parameter(Mandatory = $false)]
        [switch] $ExcludeChildren,

        [Parameter(Mandatory = $false)]
        [switch] $IncludePreview,

        [Parameter(Mandatory = $false)]
        [switch] $KeepArtifacts
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)

        Write-Verbose ('Processing module [{0}/{1}]' -f $ProviderNamespace, $ResourceType) -Verbose

        $initialLocation = (Get-Location).Path
    }

    process {

        #########################################
        ##   Temp Clone API Specs Repository   ##
        #########################################
        $repoUrl = $script:CONFIG.url_CloneRESTAPISpecRepository
        $repoName = Split-Path $repoUrl -LeafBase

        # Clone repository
        ## Create temp folder
        if (-not (Test-Path $script:temp)) {
            $null = New-Item -Path $script:temp -ItemType 'Directory'
        }
        ## Switch to temp folder
        Set-Location $script:temp

        ## Clone repository into temp folder
        if (-not (Test-Path (Join-Path $script:temp $repoName))) {
            git clone --depth=1 --single-branch --branch=main --filter=tree:0 $repoUrl
        }
        else {
            Write-Verbose "Repository [$repoName] already cloned"
        }

        Set-Location $initialLocation

        try {
            ###########################
            ##   Fetch module data   ##
            ###########################
            $getPathDataInputObject = @{
                ProviderNamespace = $ProviderNamespace
                ResourceType      = $ResourceType
                RepositoryPath    = Join-Path $script:temp $repoName
                IncludePreview    = $IncludePreview
            }
            $pathData = Get-ServiceSpecPathData @getPathDataInputObject

            # Filter Children if desired
            if ($ExcludeChildren) {
                $pathData = $pathData | Where-Object { [String]::IsNullOrEmpty($_.parentUrlPath) }
            }

            # Iterate through parent & child-paths and extract the data
            $moduleData = @()
            foreach ($pathBlock in $pathData) {
                $resolveInputObject = @{
                    JSONFilePath = $pathBlock.jsonFilePath
                    UrlPath  = $pathBlock.urlPath
                    ResourceType = $ResourceType
                }
                $resolvedParameters = Resolve-ModuleData @resolveInputObject

                # Calculate simplified identifier
                $identifier = ($pathBlock.urlPath -split '\/providers\/')[1]
                $identifierElem = $identifier -split '\/'
                $identifier = $identifierElem[0] # E.g. Microsoft.Storage
                
                if ($identifierElem.Count -gt 1) {
                    # Add the remaining elements (every 2nd as everything in between represents a 'name')
                    $remainingRelevantElem = $identifierElem[1..($identifierElem.Count)]
                    for ($index = 0; $index -lt $remainingRelevantElem.Count; $index++) {
                        if ($index % 2 -eq 0) {
                            $identifier += ('/{0}' -f $remainingRelevantElem[$index])
                        }
                    }
                }

                # Build result
                $moduleData += @{
                    data       = $resolvedParameters
                    identifier = $identifier
                    metadata   = @{
                        urlPath       = $pathBlock.urlPath
                        jsonFilePath  = $pathBlock.jsonFilePath
                        parentUrlPath = $pathBlock.parentUrlPath
                    }
                }
            }
            #######################
            ##   Create output   ##
            #######################
            # TODO: Return as expected output
            return $moduleData

        }
        catch {
            throw $_
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
