<#
.SYNOPSIS
    A PowerShell framework for automating routine SQL Server DBA tasks.

.DESCRIPTION
    This script performs index maintenance, verifies database backups, and runs a basic health check
    on a list of specified SQL Server instances. It generates an HTML report and sends it via email.

.AUTHOR
    Surya Balakrishnan

.VERSION
    1.0

.NOTES
    Requires the 'DBAtools' PowerShell module. Install with: Install-Module -Name DBATools
    This script is a template. PLEASE TEST THOROUGHLY in a non-production environment before use.
#>

#region Configuration
# ===========================================================================================
# CONFIGURE YOUR ENVIRONMENT VARIABLES HERE
# ===========================================================================================

# List of SQL Server instances to process
$SqlServerInstances = @(
    "ServerA\Instance1",
    "ServerB"
)

# Email Notification Settings
$EmailParams = @{
    SmtpServer = "smtp.yourcompany.com"
    From       = "dbareports@yourcompany.com"
    To         = "your.email@yourcompany.com"
    Subject    = "Daily SQL Server Health & Maintenance Report - $(Get-Date -Format 'yyyy-MM-dd')"
}

# Path for the log file and HTML report
$LogPath = "C:\Temp\DbaMaintenanceLog.txt"
$ReportPath = "C:\Temp\DbaReport.html"

# Thresholds
$IndexReorganizeThreshold = 10 # % fragmentation to reorganize
$IndexRebuildThreshold = 30  # % fragmentation to rebuild
$BackupComplianceHours = 26  # Databases must have a full backup within this many hours

#endregion Configuration

#region Helper Functions

function Write-Log {
    param(
        [string]$Message
    )
    $LogMessage = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] - $Message"
    Write-Host $LogMessage
    Add-Content -Path $LogPath -Value $LogMessage
}

#endregion Helper Functions

#region Main Functions

function Invoke-DbaIndexMaintenance {
    param(
        [string]$Instance
    )
    Write-Log "Starting index maintenance on $Instance..."
    try {
        # Get all non-system databases
        $databases = Get-DbaDatabase -SqlInstance $Instance -ExcludeSystem
        foreach ($db in $databases) {
            # Find fragmented indexes
            $fragmentedIndexes = Get-DbaIndex -SqlInstance $Instance -Database $db | Where-Object { $_.PercentFragmented -ge $IndexReorganizeThreshold }
            
            foreach ($index in $fragmentedIndexes) {
                $action = if ($index.PercentFragmented -ge $IndexRebuildThreshold) { "REBUILD" } else { "REORGANIZE" }
                Write-Log "Performing $action on index [$($index.Name)] in database [$db] (Fragmentation: $($index.PercentFragmented)%)"
                Repair-DbaIndex -SqlInstance $Instance -Database $db -Index $index.Name -Type $action
            }
        }
        Write-Log "Index maintenance completed for $Instance."
    }
    catch {
        Write-Log "ERROR: Index maintenance failed for $Instance. Details: $_"
    }
}

function Test-DbaBackupIntegrity {
    param(
        [string]$Instance
    )
    Write-Log "Verifying backup integrity for $Instance..."
    try {
        $backupStatus = Test-DbaLastBackup -SqlInstance $Instance
        $nonCompliant = $backupStatus | Where-Object { $_.LastFullBackup -lt (Get-Date).AddHours(-$BackupComplianceHours) }

        if ($nonCompliant) {
            foreach ($db in $nonCompliant) {
                Write-Log "ALERT: Database [$($db.Name)] on $Instance is out of backup compliance. Last backup: $($db.LastFullBackup)"
            }
            return $nonCompliant.Name
        } else {
            Write-Log "All database backups are compliant on $Instance."
            return $null
        }
    }
    catch {
        Write-Log "ERROR: Could not verify backups on $Instance. Details: $_"
        return "Verification Failed"
    }
}

function Get-DbaServerHealth {
    param(
        [string]$Instance
    )
    Write-Log "Running health checks on $Instance..."
    $healthReport = [PSCustomObject]@{
        InstanceName = $Instance
        FailedJobs = (Get-DbaAgentJob -SqlInstance $Instance -State Failed).Name -join ", "
        BackupComplianceAlerts = Test-DbaBackupIntegrity -Instance $Instance
    }
    return $healthReport
}

#endregion Main Functions

#region Execution

# --- Check for DBAtools module ---
if (-not (Get-Module -ListAvailable -Name DBATools)) {
    Write-Host "FATAL: The 'DBATools' module is required. Please run 'Install-Module -Name DBATools'." -ForegroundColor Red
    exit
}

Write-Log "--- Starting DBA Automation Framework ---"

# --- Run Maintenance Tasks (Optional - can be scheduled for different times) ---
# foreach ($instance in $SqlServerInstances) {
#     Invoke-DbaIndexMaintenance -Instance $instance
# }

# --- Run Health and Reporting Tasks ---
$allHealthReports = foreach ($instance in $SqlServerInstances) {
    Get-DbaServerHealth -Instance $instance
}

# --- Generate and Send HTML Report ---
$htmlHead = @"
<style>
    body { font-family: 'Segoe UI', sans-serif; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #dddddd; text-align: left; padding: 8px; }
    th { background-color: #f2f2f2; }
    tr:nth-child(even) { background-color: #f9f9f9; }
</style>
"@

$htmlBody = $allHealthReports | ConvertTo-Html -Head $htmlHead

try {
    Send-MailMessage @EmailParams -Body $htmlBody -BodyAsHtml
    Write-Log "Successfully sent email report."
}
catch {
    Write-Log "ERROR: Failed to send email report. Details: $_"
}

# Save report to file as well
$htmlBody | Out-File -FilePath $ReportPath

Write-Log "--- DBA Automation Framework Finished ---"

#endregion Execution