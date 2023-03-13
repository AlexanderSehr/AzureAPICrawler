<#
.SYNOPSIS
Fetch all available diagnostic metrics and logs for the given Resource Type

.DESCRIPTION
Fetch all available diagnostic metrics and logs for the given Resource Type
Leverges Microsoft Docs's [https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/azure-monitor] to fetch the data

.PARAMETER ProviderNamespace
Mandatory. The Provider Namespace to fetch the data for

.PARAMETER ResourceType
Mandatory. The Resource Type to fetch the data for

.PARAMETER diagnosticMetricsPath
Optional. The path to the file containing the mterics data.

.PARAMETER diagnosticLogsPath
Optional. The path to the file containing the logs data.

.EXAMPLE
Get-DiagnosticOptionsList -ProviderNamespace 'Microsoft.KeyVault' -ResourceType 'vaults'

Fetch the diagnostic options (logs & metrics) for Resource Type [Microsoft.KeyVault/vaults]
#>
function Get-DiagnosticOptionsList {

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ProviderNamespace,

        [Parameter(Mandatory = $true)]
        [string] $ResourceType,

        [Parameter(Mandatory = $false)]
        [string] $diagnosticMetricsPath = (Join-Path $script:temp 'diagnosticMetrics.md'),

        [Parameter(Mandatory = $false)]
        [string] $diagnosticLogsPath = (Join-Path $script:temp 'diagnosticLogs.md')
    )

    begin {
        Write-Debug ('{0} entered' -f $MyInvocation.MyCommand)
    }

    process {

        #################
        ##   METRICS   ##
        #################
        $foundMetrics = @()
        if (-not (Test-Path $diagnosticMetricsPath)) {
            Write-Verbose 'Fetching diagnostic metrics data. This may take a moment...' -Verbose
            Invoke-WebRequest -Uri $script:Config.url_MonitoringDocsRepositoryMetricsRaw -OutFile $diagnosticMetricsPath
        }
        $metricsMarkdown = Get-Content $diagnosticMetricsPath

        # Find provider in file (Note: It sometimes has excess spaces at the end)
        $matchingMetricResourceTypeLine = $metricsMarkdown.IndexOf(($metricsMarkdown -match "## $ProviderNamespace\/$ResourceType\s*$")[-1])

        if ($matchingMetricResourceTypeLine -gt -1) {

            # Find table
            $tableStartIndex = $matchingMetricResourceTypeLine
            while ($metricsMarkdown[$tableStartIndex] -notlike '|*' -and $tableStartIndex -lt $metricsMarkdown.Count) {
                $tableStartIndex++
            }
            $tableStartIndex = $tableStartIndex + 2 # Skipping table header

            $tableEndIndex = $tableStartIndex
            while ($metricsMarkdown[$tableEndIndex] -like '|*' -and $tableEndIndex -lt $metricsMarkdown.Count) {
                $tableEndIndex++
            }

            # Build result
            for ($index = $tableStartIndex; $index -lt $tableEndIndex; $index++) {
                if (($metricsMarkdown[$index] -split '\|')[2] -eq 'Yes') {
                    # If the 'Exportable' column equals 'Yes', we consider the metric
                    $foundMetrics += ($metricsMarkdown[$index] -split '\|')[1]
                }
            }
        }

        ##############
        ##   LOGS   ##
        ##############
        $foundLogs = @()
        if (-not (Test-Path $diagnosticLogsPath)) {
            Write-Verbose 'Fetching diagnostic logs data. This may take a moment...' -Verbose
            Invoke-WebRequest -Uri $script:Config.url_MonitoringDocsRepositoryLogsRaw -OutFile $diagnosticLogsPath
        }
        $logsMarkdown = Get-Content $diagnosticLogsPath

        # Find provider in file (Note: It sometimes has excess spaces at the end)
        $matchingLogResourceTypeLine = $logsMarkdown.IndexOf(($logsMarkdown -match "## $ProviderNamespace\/$ResourceType\s*$")[-1])
        if ($matchingLogResourceTypeLine -gt -1) {

            # Find table
            $tableStartIndex = $matchingLogResourceTypeLine
            while ($logsMarkdown[$tableStartIndex] -notlike '|*' -and $tableStartIndex -lt $logsMarkdown.Count) {
                $tableStartIndex++
            }
            $tableStartIndex = $tableStartIndex + 2 # Skipping table header

            $tableEndIndex = $tableStartIndex
            while ($logsMarkdown[$tableEndIndex] -like '|*' -and $tableEndIndex -lt $logsMarkdown.Count) {
                $tableEndIndex++
            }

            # Build result
            for ($index = $tableStartIndex; $index -lt $tableEndIndex; $index++) {
                $foundLogs += ($logsMarkdown[$index] -split '\|')[1]
            }
        }

        return [PSCustomObject]@{
            Metrics = $foundMetrics
            Logs    = $foundLogs
        }
    }

    end {
        Write-Debug ('{0} exited' -f $MyInvocation.MyCommand)
    }
}
