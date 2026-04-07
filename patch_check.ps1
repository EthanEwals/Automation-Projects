# Input and output files
$InputFile = "systems.csv"
$OutputFile = "patch_report_ps.csv"


# Function to validate criticality
function Test-CriticalityValid {
    param([string]$Criticality)
    $validCriticalities = @("Low", "Medium", "High", "Critical")
    return $validCriticalities -contains $Criticality
}

# Function to calculate days since patch
function Get-DaysSincePatch {
    param([string]$PatchDate)
    try {
        $patchDateTime = [DateTime]::ParseExact($PatchDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        $timespan = New-TimeSpan -Start $patchDateTime -End (Get-Date)
        return $timespan.Days
    }
    catch {
        return "Invalid"
    }
}

# Function to get compliance status
function Get-ComplianceStatus {
    param([object]$Days)
    
    if ($Days -eq "Invalid") {
        return "❌ Invalid Date"
    }
    elseif ($Days -le 30) {
        return "✅ Compliant"
    }
    elseif ($Days -le 59) {
        return "⚠️ Warning"
    }
    else {
        return "❌ Outdated"
    }
}

# Function to get criticality weight
function Get-CriticalityWeight {
    param([string]$Criticality)
    
    switch ($Criticality) {
        "Low" { return 1 }
        "Medium" { return 2 }
        "High" { return 3 }
        "Critical" { return 4 }
        default { return 0 }
    }
}

# Function to calculate risk score
function Get-RiskScore {
    param([object]$Days, [string]$Criticality)
    
    if ($Days -eq "Invalid") {
        return 10.0
    }
    
    $weight = Get-CriticalityWeight -Criticality $Criticality
    $risk = ($Days / 10) + $weight
    return [math]::Round($risk, 2)
}

# Function to get console color for status
function Get-StatusColor {
    param([string]$Status)
    
    if ($Status -like "*Compliant*") {
        return "Green"
    }
    elseif ($Status -like "*Warning*") {
        return "Yellow"
    }
    elseif ($Status -like "*Outdated*" -or $Status -like "*Invalid*") {
        return "Red"
    }
    else {
        return "White"
    }
}

# Main execution
try {
    # Check if input file exists
    if (-not (Test-Path $InputFile)) {
        Write-Host "Error: $InputFile not found!" -ForegroundColor Red
        exit 1
    }

    # Import and validate CSV
    Write-Host "=== Patch Compliance Report ===" -ForegroundColor Blue
    Write-Host "Generated on: $(Get-Date)" -ForegroundColor Blue
    Write-Host ""

    $systems = Import-Csv -Path $InputFile
    $processedSystems = @()
    $summary = @{
        Total = 0
        Compliant = 0
        Warning = 0
        Outdated = 0
        TotalRisk = 0
    }

    # Process each system
    foreach ($system in $systems) {
        # Skip if any required field is missing
        if (-not $system.Hostname -or -not $system.OS -or -not $system.LastPatchDate -or -not $system.Criticality) {
            Write-Host "Warning: Skipping system with missing data: $($system.Hostname)" -ForegroundColor Yellow
            continue
        }

        # Validate criticality
        if (-not (Test-CriticalityValid -Criticality $system.Criticality)) {
            Write-Host "Warning: Skipping invalid criticality for $($system.Hostname): $($system.Criticality)" -ForegroundColor Yellow
            continue
        }

        # Validate date
        if (-not (Test-DateValid -DateString $system.LastPatchDate)) {
            Write-Host "Warning: Skipping invalid date for $($system.Hostname): $($system.LastPatchDate)" -ForegroundColor Yellow
            continue
        }

        # Calculate metrics
        $daysSincePatch = Get-DaysSincePatch -PatchDate $system.LastPatchDate
        $complianceStatus = Get-ComplianceStatus -Days $daysSincePatch
        $riskScore = Get-RiskScore -Days $daysSincePatch -Criticality $system.Criticality

        # Update summary
        $summary.Total++
        switch ($complianceStatus) {
            "✅ Compliant" { $summary.Compliant++ }
            "⚠️ Warning" { $summary.Warning++ }
            "❌ Outdated" { $summary.Outdated++ }
        }
        $summary.TotalRisk += $riskScore

        # Create custom object with all properties
        $systemObj = [PSCustomObject]@{
            Hostname = $system.Hostname
            OS = $system.OS
            LastPatchDate = $system.LastPatchDate
            Criticality = $system.Criticality
            DaysSincePatch = $daysSincePatch
            ComplianceStatus = $complianceStatus
            RiskScore = $riskScore
        }

        $processedSystems += $systemObj
    }

    # Sort by risk score (highest first)
    $sortedSystems = $processedSystems | Sort-Object -Property RiskScore -Descending

    # Display color-coded results
    Write-Host "=== Systems Sorted by Risk Score (Highest First) ===" -ForegroundColor Blue
    Write-Host ""

    foreach ($system in $sortedSystems) {
        $color = Get-StatusColor -Status $system.ComplianceStatus
        Write-Host ("{0,-15} {1,-10} {2,-12} {3,-10} {4,-4} {5,-15} {6,-6}" -f 
            $system.Hostname, $system.OS, $system.LastPatchDate, $system.Criticality, 
            $system.DaysSincePatch, $system.ComplianceStatus, $system.RiskScore) -ForegroundColor $color
    }

    # Export to CSV
    $sortedSystems | Export-Csv -Path $OutputFile -NoTypeInformation

    # Display summary
    $averageRisk = if ($summary.Total -gt 0) { [math]::Round($summary.TotalRisk / $summary.Total, 2) } else { 0 }

    Write-Host ""
    Write-Host "=== Compliance Summary ===" -ForegroundColor Blue
    Write-Host "Total Systems Checked: $($summary.Total)"
    Write-Host "✅ Compliant: $($summary.Compliant)" -ForegroundColor Green
    Write-Host "⚠️ Warning: $($summary.Warning)" -ForegroundColor Yellow
    Write-Host "❌ Outdated: $($summary.Outdated)" -ForegroundColor Red
    Write-Host "Average Risk Score: $averageRisk"

    Write-Host ""
    Write-Host "Report exported to: $OutputFile" -ForegroundColor Green

}
catch {
    Write-Host "Error processing systems: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error details: $($_.ScriptStackTrace)" -ForegroundColor Red
}
