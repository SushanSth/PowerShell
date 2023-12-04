#Updating IpInterfaceMetric and NetworkOutageTime in AOVPN User and Device Tunnel in Rasphone.pbk
 
# Define the names of the VPN connections corresponding to AOVPN User Tunnel and AOVPN Device Tunnel
$userTunnelVpnConnectionName = "AOVPN User Tunnel"
$deviceTunnelVpnConnectionName = "AOVPN Device Tunnel"

# Check if both VPN connections exist
$userTunnelExists = Get-VpnConnection -Name $userTunnelVpnConnectionName -ErrorAction SilentlyContinue
$deviceTunnelExists = Get-VpnConnection -Name $deviceTunnelVpnConnectionName -ErrorAction SilentlyContinue

# If either connection doesn't exist, print a message and exit
if (-not $userTunnelExists -or -not $deviceTunnelExists) {
    Write-Host "AOVPN User Tunnel or AOVPN Device Tunnel not found. Exiting script."
    exit
}


# Define the configuration file path
$configFilePath = "C:\ProgramData\Microsoft\Network\Connections\Pbk\rasphone.pbk"

# Read the content of the configuration file
$configContent = Get-Content $configFilePath -Raw

# Define the search strings for [AOVPN User Tunnel] and [AOVPN Device Tunnel] sections
$userTunnelSection = "[AOVPN User Tunnel]"
$deviceTunnelSection = "[AOVPN Device Tunnel]"

# Define the values to be set
$ipMetricValueToUpdate = "IpInterfaceMetric=9"
$networkOutageValueToUpdate = "NetworkOutageTime=60"

# Function to update or add metric in a section
function UpdateSectionMetric($sectionContent, $metricName, $metricToUpdate, $afterMetricName) {
    # Check if the metric already exists in the section
    if ($sectionContent -match "$metricName=\S+") {
        # Update the existing metric value
        $sectionContent = $sectionContent -replace "$metricName=\S+", $metricToUpdate
    } else {
        # Check if the metric specified by $afterMetricName exists
        $afterMetricExists = $sectionContent -match "$afterMetricName"

        # If $afterMetricName exists, add metric after it; otherwise, add metric at the end
        if ($afterMetricExists) {
            $sectionContent = $sectionContent -replace "$afterMetricName", "$afterMetricName`r`n$metricToUpdate"
        } else {
            # Add metric to the section
            $sectionContent += "`r`n$metricToUpdate"
        }
    }

    return $sectionContent
}

# Iterate through both sections
foreach ($section in @($userTunnelSection, $deviceTunnelSection)) {
    # Check if the section exists in the configuration
    if ($configContent -match $section) {
        $sectionStartIndex = $configContent.IndexOf($section)
        $nextSectionStartIndex = $configContent.IndexOf("[", $sectionStartIndex + 1)

        # Determine the length of the section content
        $length = if ($nextSectionStartIndex -gt 0) {
            $nextSectionStartIndex - $sectionStartIndex
        } else {
            $configContent.Length - $sectionStartIndex
        }

        # Extract the content of the section
        $sectionContent = $configContent.Substring($sectionStartIndex, $length).Trim()

        # Call the UpdateSectionMetric function with the current section's name for IpMetricInterface
        $updatedSectionContent = UpdateSectionMetric $sectionContent "IpInterfaceMetric" $ipMetricValueToUpdate "IpPrioritizeRemote=0"

        # Replace the original section content with the updated content for IpMetricInterface
        $configContent = $configContent -replace [regex]::Escape($sectionContent), $updatedSectionContent

        # Call the UpdateSectionMetric function with the current section's name for NetworkOutageTime
        $updatedSectionContent = UpdateSectionMetric $sectionContent "NetworkOutageTime" $networkOutageValueToUpdate "DisableMobility=0"

        # Replace the original section content with the updated content for NetworkOutageTime
        $configContent = $configContent -replace [regex]::Escape($sectionContent), $updatedSectionContent
    } else {
        # If the section doesn't exist, add it to the end of the file with metrics
        $configContent += "`r`n`r`n$section`r`nIpPrioritizeRemote=0`r`n$ipMetricValueToUpdate`r`nDisableMobility=0`r`n$networkOutageValueToUpdate"
    }
}

# Write the updated content back to the configuration file
$configContent | Set-Content $configFilePath
