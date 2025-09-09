# Cybersecurity Incident Timeline Generator
# Converts CSV incident data to animated HTML visualization

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

# Extract unique hosts
$allHosts = @()
$allHosts += $incidentData | ForEach-Object { $_.SourceHost; $_.DestinationHost } | 
    Where-Object { $_ -and $_ -ne "External" } | 
    Select-Object -Unique | 
    Sort-Object

Write-Host "Found $($allHosts.Count) unique hosts" -ForegroundColor Green

# Extract perimeter devices
$perimeterDevices = $incidentData | 
    Where-Object { $_.PerimeterDevice } | 
    Select-Object -ExpandProperty PerimeterDevice -Unique

Write-Host "Found $($perimeterDevices.Count) perimeter devices" -ForegroundColor Green

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

# Convert to JSON
$hostsJson = $allHosts | ConvertTo-Json -Compress
$perimeterJson = $perimeterDevices | ConvertTo-Json -Compress
$eventsJson = $timelineEvents | ConvertTo-Json -Compress -Depth 10

# Read template
Write-Host "Loading HTML template..." -ForegroundColor Cyan
$template = Get-Content $TemplatePath -Raw

if ($perimeterJson -notlike "*[*]*") {
    # Build regex with RightToLeft
    $regex = New-Object System.Text.RegularExpressions.Regex('"')
    $perimeterJson =  $regex.Replace($perimeterJson,'["',1)
    # Build regex with RightToLeft
    $regex = New-Object System.Text.RegularExpressions.Regex('"', [System.Text.RegularExpressions.RegexOptions]::RightToLeft)
    $perimeterJson =  $regex.Replace($perimeterJson,'"]',1)
}

# Replace placeholders
$html = $template
$html = $html -replace '{{INCIDENT_TITLE}}', $IncidentTitle
$html = $html -replace '{{HOSTS_DATA}}', $hostsJson
$html = $html -replace '{{PERIMETER_DEVICES}}', $perimeterJson
$html = $html -replace '{{TIMELINE_EVENTS}}', $eventsJson

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
    TotalEvents = $incidentData.Count
    UniqueHosts = $allHosts.Count
    PerimeterDevices = $perimeterDevices.Count
    TimeSpan = "$totalMinutes minutes"
    UniqueMitreTechniques = ($incidentData | Select-Object -ExpandProperty MitreAttackID -Unique | Where-Object { $_ }).Count
    LateralMovements = ($incidentData | Where-Object { $_.LateralMovementMethod }).Count
}

Write-Host "`nIncident Timeline Summary:" -ForegroundColor Yellow
Write-Host "=========================" -ForegroundColor Yellow
foreach ($stat in $stats.GetEnumerator()) {
    Write-Host "$($stat.Key): $($stat.Value)" -ForegroundColor White
}

Write-Host "`nHTML timeline generated successfully!" -ForegroundColor Green
Write-Host "Output file: $OutputPath" -ForegroundColor Green
Write-Host "`nOpen the HTML file in a modern web browser to view the animated timeline." -ForegroundColor Cyan

# Option to open in default browser
$openBrowser = Read-Host "`nOpen in browser now? (Y/N)"
if ($openBrowser -eq 'Y' -or $openBrowser -eq 'y') {
    Start-Process $OutputPath
}
