# Cybersecurity Incident Timeline Generator
# Converts CSV incident data to animated HTML visualization
# Supports two scenarios:
#   1. External threat actor compromising perimeter device (IsInitialAccess=TRUE)
#   2. Internal beachhead downloading malicious payload from external host

param(
    [Parameter(Mandatory=$true)]
    [string]$CsvPath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "incident_timeline.html",
    
    [Parameter(Mandatory=$true)]
    [string]$TemplatePath,
    
    [Parameter(Mandatory=$false)]
    [string]$IncidentTitle = "Cybersecurity Incident Timeline"
)

# Validate input file
if (-not (Test-Path $CsvPath)) {
    Write-Error "CSV file not found: $CsvPath"
    exit 1
}

if (-not (Test-Path $TemplatePath)) {
    Write-Error "Template file not found: $TemplatePath"
    exit 1
}

Write-Host "Reading CSV data..." -ForegroundColor Cyan
$incidentData = Import-Csv $CsvPath

# Validate CSV structure
$requiredColumns = @(
    'Timestamp', 'SourceHost', 'DestinationHost', 'Action', 
    'LateralMovementMethod', 'ToolsUsed', 'FilesInvolved', 
    'Details', 'MitreAttackID', 'MitreAttackTechnique', 
    'PerimeterDevice', 'IsInitialAccess'
)

$csvColumns = $incidentData[0].PSObject.Properties.Name
$missingColumns = $requiredColumns | Where-Object { $_ -notin $csvColumns }

if ($missingColumns.Count -gt 0) {
    Write-Error "Missing required columns: $($missingColumns -join ', ')"
    exit 1
}

Write-Host "Processing incident data..." -ForegroundColor Cyan

# Sort events by timestamp
$incidentData = $incidentData | Sort-Object { [datetime]$_.Timestamp }

# Determine attack scenario
$firstEvent = $incidentData[0]
$attackScenario = "unknown"

if ($firstEvent.SourceHost -eq "External" -and $firstEvent.IsInitialAccess -eq "TRUE") {
    $attackScenario = "external_to_perimeter"
    Write-Host "Detected Scenario: External Threat Actor → Perimeter Device" -ForegroundColor Yellow
} elseif ($firstEvent.DestinationHost -eq "External" -or 
          ($firstEvent.SourceHost -ne "External" -and $firstEvent.IsInitialAccess -eq "TRUE")) {
    $attackScenario = "internal_to_external"
    Write-Host "Detected Scenario: Internal Beachhead → External Malicious Host" -ForegroundColor Yellow
} else {
    Write-Host "Detected Scenario: Standard Lateral Movement" -ForegroundColor Yellow
}

# Extract perimeter devices (only for external_to_perimeter scenario)
$perimeterDevices = @()
if ($attackScenario -eq "external_to_perimeter") {
    $perimeterDevices = $incidentData | 
        Where-Object { $_.PerimeterDevice -and $_.IsInitialAccess -eq "TRUE" } | 
        Select-Object -ExpandProperty PerimeterDevice -Unique
    
    Write-Host "Found $($perimeterDevices.Count) perimeter devices" -ForegroundColor Green
}

# Extract unique INTERNAL hosts only
# Exclude: External, and any host that is ONLY a perimeter device in initial access
$allHosts = @()

foreach ($event in $incidentData) {
    # Add source if it's internal
    if ($event.SourceHost -and 
        $event.SourceHost -ne "External" -and 
        $event.SourceHost -notin $perimeterDevices) {
        $allHosts += $event.SourceHost
    }
    
    # Add destination if it's internal
    # For external_to_perimeter: Don't add destination if it's the initial access perimeter device
    if ($event.DestinationHost -and 
        $event.DestinationHost -ne "External") {
        
        # Check if this is an initial access to perimeter device
        $isInitialPerimeterHit = ($attackScenario -eq "external_to_perimeter" -and 
                                  $event.IsInitialAccess -eq "TRUE" -and 
                                  $event.DestinationHost -eq $event.PerimeterDevice)
        
        if (-not $isInitialPerimeterHit -and $event.DestinationHost -notin $perimeterDevices) {
            $allHosts += $event.DestinationHost
        }
    }
}

# Get unique hosts and sort
$allHosts = $allHosts | Select-Object -Unique | Sort-Object

Write-Host "Found $($allHosts.Count) unique internal hosts" -ForegroundColor Green

# Identify beachhead host (for internal_to_external scenario)
$beachheadHost = ""
if ($attackScenario -eq "internal_to_external") {
    $beachheadHost = $firstEvent.SourceHost
    Write-Host "Beachhead host: $beachheadHost" -ForegroundColor Yellow
}

# Build timeline events for JavaScript
$timelineEvents = @()
$eventId = 0

foreach ($event in $incidentData) {
    $eventObj = @{
        id = $eventId++
        timestamp = $event.Timestamp
        sourceHost = $event.SourceHost
        destinationHost = $event.DestinationHost
        action = $event.Action
        lateralMovement = $event.LateralMovementMethod
        tools = $event.ToolsUsed
        files = $event.FilesInvolved
        details = $event.Details -replace "`r`n", "\n" -replace "`n", "\n" -replace '"', '\"'
        mitreId = $event.MitreAttackID
        mitreTechnique = $event.MitreAttackTechnique
        perimeterDevice = $event.PerimeterDevice
        isInitialAccess = [bool]($event.IsInitialAccess -eq "TRUE")
    }
    $timelineEvents += $eventObj
}

# Convert to JSON - Force arrays even for single items
if ($allHosts.Count -eq 0) {
    $hostsJson = "[]"
} else {
    # Use array subexpression to force array conversion
    $hostsJson = ConvertTo-Json -InputObject @($allHosts) -Compress
}

if ($perimeterDevices.Count -eq 0) {
    $perimeterJson = "[]"
} else {
    # Use array subexpression to force array conversion
    $perimeterJson = ConvertTo-Json -InputObject @($perimeterDevices) -Compress
}

$eventsJson = $timelineEvents | ConvertTo-Json -Compress -Depth 10

# Read template
Write-Host "Loading HTML template..." -ForegroundColor Cyan
$template = Get-Content $TemplatePath -Raw

# Replace placeholders
$html = $template
$html = $html -replace '{{INCIDENT_TITLE}}', $IncidentTitle
$html = $html -replace '{{HOSTS_DATA}}', $hostsJson
$html = $html -replace '{{PERIMETER_DEVICES}}', $perimeterJson
$html = $html -replace '{{TIMELINE_EVENTS}}', $eventsJson
$html = $html -replace '{{ATTACK_SCENARIO}}', $attackScenario
$html = $html -replace '{{BEACHHEAD_HOST}}', $beachheadHost

# Calculate timeline duration (for animation timing)
$firstEvent = [datetime]$incidentData[0].Timestamp
$lastEvent = [datetime]$incidentData[-1].Timestamp
$totalMinutes = [math]::Ceiling(($lastEvent - $firstEvent).TotalMinutes)

$html = $html -replace '{{TOTAL_DURATION}}', $totalMinutes.ToString()
$html = $html -replace '{{START_TIME}}', $firstEvent.ToString("yyyy-MM-dd HH:mm:ss")
$html = $html -replace '{{END_TIME}}', $lastEvent.ToString("yyyy-MM-dd HH:mm:ss")

# Write output
Write-Host "Generating HTML output..." -ForegroundColor Cyan
$html | Out-File -FilePath $OutputPath -Encoding UTF8

# Generate summary statistics
$stats = @{
    AttackScenario = $attackScenario
    TotalEvents = $incidentData.Count
    UniqueInternalHosts = $allHosts.Count
    PerimeterDevices = $perimeterDevices.Count
    BeachheadHost = if ($beachheadHost) { $beachheadHost } else { "N/A" }
    TimeSpan = "$totalMinutes minutes"
    UniqueMitreTechniques = ($incidentData | Select-Object -ExpandProperty MitreAttackID -Unique | Where-Object { $_ }).Count
    LateralMovements = ($incidentData | Where-Object { $_.LateralMovementMethod }).Count
}

Write-Host "`nIncident Timeline Summary:" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow
foreach ($stat in $stats.GetEnumerator() | Sort-Object Name) {
    Write-Host "$($stat.Key): $($stat.Value)" -ForegroundColor White
}

Write-Host "`nData Validation:" -ForegroundColor Yellow
Write-Host "Hosts JSON: $hostsJson" -ForegroundColor Cyan
Write-Host "Perimeter JSON: $perimeterJson" -ForegroundColor Cyan
Write-Host "Events count: $($timelineEvents.Count)" -ForegroundColor Cyan

Write-Host "`nHTML timeline generated successfully!" -ForegroundColor Green
Write-Host "Output file: $OutputPath" -ForegroundColor Green
Write-Host "`nOpen the HTML file in a modern web browser to view the animated timeline." -ForegroundColor Cyan

# Option to open in default browser
$openBrowser = Read-Host "`nOpen in browser now? (Y/N)"
if ($openBrowser -eq 'Y' -or $openBrowser -eq 'y') {
    Start-Process $OutputPath
}
