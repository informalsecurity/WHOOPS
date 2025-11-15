# Quick Test Script for Timeline Generator
# This helps debug what's being generated

param(
    [Parameter(Mandatory=$true)]
    [string]$CsvPath,
    
    [Parameter(Mandatory=$false)]
    [string]$TemplatePath = "timeline_template.html"
)

Write-Host "=== TIMELINE GENERATOR DEBUG TEST ===" -ForegroundColor Cyan

# Read CSV
Write-Host "`nReading CSV..." -ForegroundColor Yellow
$data = Import-Csv $CsvPath

Write-Host "Total events: $($data.Count)" -ForegroundColor White
Write-Host "First event:" -ForegroundColor White
$data[0] | Format-List

# Determine scenario
$firstEvent = $data[0]
if ($firstEvent.SourceHost -eq "External" -and $firstEvent.IsInitialAccess -eq "TRUE") {
    $scenario = "external_to_perimeter"
    Write-Host "`nDetected Scenario: EXTERNAL → PERIMETER" -ForegroundColor Green
} elseif ($firstEvent.DestinationHost -eq "External" -or 
          ($firstEvent.SourceHost -ne "External" -and $firstEvent.IsInitialAccess -eq "TRUE")) {
    $scenario = "internal_to_external"
    Write-Host "`nDetected Scenario: INTERNAL BEACHHEAD → EXTERNAL" -ForegroundColor Green
} else {
    $scenario = "unknown"
    Write-Host "`nDetected Scenario: UNKNOWN" -ForegroundColor Red
}

# Extract perimeter devices
$perimeterDevices = @()
if ($scenario -eq "external_to_perimeter") {
    $perimeterDevices = $data | 
        Where-Object { $_.PerimeterDevice -and $_.IsInitialAccess -eq "TRUE" } | 
        Select-Object -ExpandProperty PerimeterDevice -Unique
}

Write-Host "`nPerimeter Devices: $($perimeterDevices.Count)" -ForegroundColor Yellow
$perimeterDevices | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

# Extract internal hosts
Write-Host "`nExtracting internal hosts..." -ForegroundColor Yellow
$allHosts = @()

foreach ($event in $data) {
    # Add source if internal
    if ($event.SourceHost -and 
        $event.SourceHost -ne "External" -and 
        $event.SourceHost -notin $perimeterDevices) {
        $allHosts += $event.SourceHost
    }
    
    # Add destination if internal
    if ($event.DestinationHost -and 
        $event.DestinationHost -ne "External") {
        
        $isInitialPerimeterHit = ($scenario -eq "external_to_perimeter" -and 
                                  $event.IsInitialAccess -eq "TRUE" -and 
                                  $event.DestinationHost -eq $event.PerimeterDevice)
        
        if (-not $isInitialPerimeterHit -and $event.DestinationHost -notin $perimeterDevices) {
            $allHosts += $event.DestinationHost
        }
    }
}

$allHosts = $allHosts | Select-Object -Unique | Sort-Object

Write-Host "Internal Hosts: $($allHosts.Count)" -ForegroundColor Yellow
$allHosts | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }

# Identify beachhead
$beachheadHost = ""
if ($scenario -eq "internal_to_external") {
    $beachheadHost = $firstEvent.SourceHost
    Write-Host "`nBeachhead Host: $beachheadHost" -ForegroundColor Yellow
}

# Test JSON conversion
Write-Host "`n=== JSON CONVERSION TEST ===" -ForegroundColor Cyan

if ($allHosts.Count -eq 0) {
    $hostsJson = "[]"
} else {
    $hostsJson = ConvertTo-Json -InputObject @($allHosts) -Compress
}

if ($perimeterDevices.Count -eq 0) {
    $perimeterJson = "[]"
} else {
    $perimeterJson = ConvertTo-Json -InputObject @($perimeterDevices) -Compress
}

Write-Host "`nHosts JSON:" -ForegroundColor Yellow
Write-Host $hostsJson -ForegroundColor White

Write-Host "`nPerimeter JSON:" -ForegroundColor Yellow
Write-Host $perimeterJson -ForegroundColor White

Write-Host "`nScenario: $scenario" -ForegroundColor Yellow
Write-Host "Beachhead: $beachheadHost" -ForegroundColor Yellow

Write-Host "`n=== TEST COMPLETE ===" -ForegroundColor Cyan
Write-Host "If the JSON looks correct, run the full generator script." -ForegroundColor Green