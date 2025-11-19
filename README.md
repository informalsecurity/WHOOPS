# WHOOPS - Watch How Operators Orchestrate Payload Sequences
## Cybersecurity Incident Timeline Visualizer

## Overview
This tool converts CSV incident data into an interactive, animated HTML visualization showing the progression of cybersecurity incidents. It supports two primary attack scenarios with automatic detection and appropriate visualization.

## Supported Scenarios

### Scenario 1: External Threat Actor → Perimeter Device
**Description**: An external attacker compromises a perimeter device (firewall, VPN gateway, web server) to gain initial access, then moves laterally through the internal network.

**Characteristics**:
- First event has `SourceHost = "External"`
- First event has `IsInitialAccess = TRUE`
- First event has `PerimeterDevice` populated with the compromised device name
- Visualization shows threat actor entering from left, attacking perimeter device, then moving to internal hosts

**Example Use Case**: VPN credential stuffing attack, web server exploitation, firewall vulnerability

### Scenario 2: Internal Beachhead → External Malicious Host
**Description**: An internal system (workstation, laptop) reaches out to an external malicious host to download malware, becoming a beachhead for further attacks.

**Characteristics**:
- First event has `DestinationHost = "External"`
- First event has `IsInitialAccess = TRUE`
- Source host becomes the beachhead (highlighted in gold)
- Visualization shows internal system reaching out to external malicious host, then spreading internally

**Example Use Case**: Phishing email with malicious link, drive-by download, malicious attachment execution

## Files Included

1. **Generate-IncidentTimeline.ps1** - PowerShell script that processes CSV and generates HTML
2. **timeline_template.html** - HTML template with embedded JavaScript for visualization
3. **example_scenario1_external_to_perimeter.csv** - Example CSV for Scenario 1
4. **example_scenario2_internal_beachhead.csv** - Example CSV for Scenario 2

## CSV Format

### Required Columns

| Column Name | Description | Example |
|------------|-------------|---------|
| Timestamp | ISO 8601 timestamp of the event | 2029-01-13T01:08:00-04:00 |
| SourceHost | Origin system of the action | External, WORKSTATION-12, DC01 |
| DestinationHost | Target system of the action | VPN-Gateway, FILE-SERVER-01, External |
| Action | Description of the action taken | Initial compromise, Lateral movement, Data exfiltration |
| LateralMovementMethod | Method used for lateral movement | RDP, SMB, WMI, VPN |
| ToolsUsed | Tools/software used in the attack | Mimikatz, PsExec, PowerShell |
| FilesInvolved | Files created/modified/exfiltrated | lsass.dmp, malware.exe, data.zip |
| Details | Technical details of the event | Command lines, IP addresses, detailed description |
| MitreAttackID | MITRE ATT&CK technique ID | T1078, T1021.001, T1003.001 |
| MitreAttackTechnique | MITRE ATT&CK technique name | Valid Accounts, Remote Desktop Protocol |
| PerimeterDevice | Name of perimeter device (if applicable) | VPN-Gateway, ASA-Firewall |
| IsInitialAccess | TRUE if this is the initial compromise | TRUE or FALSE |

### CSV Guidelines

**For Scenario 1 (External → Perimeter)**:
- First row must have: `SourceHost = "External"`, `IsInitialAccess = TRUE`, `PerimeterDevice = [device name]`
- The `PerimeterDevice` value should match the `DestinationHost` in the first row
- Do NOT add the perimeter device to the internal host list - it's handled automatically
- Subsequent rows show lateral movement from perimeter device or compromised hosts

**For Scenario 2 (Internal Beachhead)**:
- First row must have: `DestinationHost = "External"`, `IsInitialAccess = TRUE`
- `SourceHost` in first row is the beachhead system
- Leave `PerimeterDevice` blank or set to NA
- Subsequent rows show lateral movement from beachhead

**Multi-line Fields**:
You can include multiple values in these fields using line breaks within the CSV cell:
- **MitreAttackID**: Multiple technique IDs (one per line)
- **MitreAttackTechnique**: Multiple technique names (one per line)
- **Details**: Multi-line technical details
- **ToolsUsed**: Multiple tools (one per line)
- **FilesInvolved**: Multiple files (one per line)

**Example with multiple MITRE techniques**:
```csv
MitreAttackID,MitreAttackTechnique
"T1003.001
T1134.001","LSASS Memory
Access Token Manipulation: Token Impersonation/Theft"
```

This will display as:
```
MITRE ATT&CK Mapping:
LSASS Memory
[T1003.001]

Access Token Manipulation: Token Impersonation/Theft
[T1134.001]
```

## Usage

### Basic Usage

```powershell
.\Generate-IncidentTimeline.ps1 `
    -CsvPath "incident_data.csv" `
    -TemplatePath "timeline_template.html" `
    -OutputPath "my_incident.html" `
    -IncidentTitle "January 2029 Ransomware Attack"
```

### Parameters

- **CsvPath** (Required): Path to your CSV file containing incident data
- **TemplatePath** (Required): Path to the HTML template file
- **OutputPath** (Optional): Output HTML file path (default: incident_timeline.html)
- **IncidentTitle** (Optional): Title for the visualization (default: Cybersecurity Incident Timeline)

### Example Commands

**Scenario 1 Example**:
```powershell
.\Generate-IncidentTimeline.ps1 `
    -CsvPath "example_scenario1_external_to_perimeter.csv" `
    -TemplatePath "timeline_template.html" `
    -OutputPath "vpn_breach_timeline.html" `
    -IncidentTitle "VPN Gateway Compromise - January 2029"
```

**Scenario 2 Example**:
```powershell
.\Generate-IncidentTimeline.ps1 `
    -CsvPath "example_scenario2_internal_beachhead.csv" `
    -TemplatePath "timeline_template.html" `
    -OutputPath "phishing_attack_timeline.html" `
    -IncidentTitle "Phishing Campaign - Employee Workstation Compromise"
```

## Visualization Features

### Interactive Controls

- **Play/Pause**: Start or pause the animated timeline
- **Restart**: Reset the visualization to the beginning
- **Speed Controls**: Adjust playback speed (0.5x, 1x, 2x, 5x)
- **Progress Bar**: Shows progression through the incident timeline
- **Keyboard Shortcuts**:
  - `Spacebar`: Play/Pause
  - `R`: Restart
  - `Esc`: Close event details modal

### Visual Elements

**Scenario 1 Visual Layout**:
```
External Threat    Perimeter       Internal Network
    (left)         (center-left)      (right arc)
      ☠     →→→   🛡️ VPN-Gateway  →→→  💻 Hosts
```

**Scenario 2 Visual Layout**:
```
Malicious Host     Internal Network
    (left)            (right arc)
      ⚠️    ←←←    💻 Beachhead ⚠️
                        ↓
                   💻 Other Hosts
```

**Both scenarios keep external/malicious elements on the left side for consistency and to prevent modal overlap.**

### Color Coding

- **Blue Circle**: Clean, uncompromised system
- **Red Circle**: Compromised system
- **Gold/Yellow Circle**: Beachhead host (Scenario 2)
- **Green Circle**: Perimeter device (Scenario 1)
- **Gray Lines**: Normal network connections
- **Red Animated Lines**: Active attack paths

### Event Details Modal

Click on any event or wait for the modal to appear during playback to see:
- Action description
- Attack path (source → destination)
- Lateral movement method
- Tools used
- Files involved
- Technical details
- MITRE ATT&CK technique mapping

## Key Fixes from Original Version

### Problem 1: Perimeter Device Duplication
**Original Issue**: Destination host in first event was added as both perimeter device AND internal host, causing confusion.

**Fix**: 
- PowerShell script now excludes perimeter devices from internal host list
- Only adds hosts as internal if they're NOT initial access perimeter devices
- Proper separation between perimeter and internal network zones

### Problem 2: Internal Beachhead Scenario Not Supported
**Original Issue**: Could only visualize external → internal attacks.

**Fix**:
- Added scenario detection logic in PowerShell
- Separate visualization logic for internal → external downloads
- Beachhead host gets special highlighting and positioning
- External malicious host shown on right side instead of left

### Problem 3: Confusing Animation Flow
**Original Issue**: Not always clear which host was the entry point.

**Fix**:
- Scenario 1: Threat actor element follows the attack from external → perimeter → internal
- Scenario 2: Beachhead highlighted in gold, shows download from external, then spread
- Clearer visual distinction between scenarios

## Tips for Best Results

1. **Accurate Timestamps**: Use precise timestamps to show realistic attack progression
2. **Clear Descriptions**: Write detailed but concise action descriptions
3. **MITRE Mapping**: Include MITRE ATT&CK IDs for professional incident reports
4. **Logical Flow**: Ensure each event logically follows from previous compromises
5. **Complete Details**: Fill in technical details for forensic value
6. **Test Both Scenarios**: Make sure your CSV format matches the intended scenario

## Troubleshooting

### "Perimeter device appearing as internal host"
- Check that first row has `IsInitialAccess = TRUE`
- Verify `PerimeterDevice` column matches `DestinationHost` in first row
- Ensure no other rows reference this device as internal

### "Animation doesn't show beachhead correctly"
- Verify first row has `DestinationHost = "External"`
- Check that `IsInitialAccess = TRUE` in first row
- Make sure subsequent rows show lateral movement from beachhead host

### "Hosts missing from visualization"
- Check CSV for typos in hostnames
- Verify hosts are referenced in at least one event
- Ensure CSV has all required columns

### "Events not animating"
- Verify timestamps are in ISO 8601 format
- Check that events are chronologically ordered
- Ensure browser is modern (Chrome, Firefox, Edge)

## Browser Compatibility

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Edge 90+
- ✅ Safari 14+
- ⚠️ Internet Explorer: Not supported

## Future Enhancements

Potential features for future versions:
- [ ] Email delivery animation for phishing scenarios
- [ ] Network traffic volume indicators
- [ ] Multiple concurrent attack paths
- [ ] Export timeline as video
- [ ] Integration with SIEM data
- [ ] Real-time data streaming

## Credits

Created for cybersecurity incident response and training purposes.
Uses MITRE ATT&CK framework for technique classification.

## License

This tool is provided as-is for educational and incident response purposes.
