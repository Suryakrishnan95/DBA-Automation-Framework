# SQL Server DBA Task Automation Framework

This repository contains a PowerShell framework designed to automate routine maintenance and health check tasks for Microsoft SQL Server. It is intended to be used as a portfolio piece to demonstrate skills in PowerShell scripting, automation, and SQL Server administration.

## Features

-   **Index Maintenance:** Automatically detects and repairs index fragmentation based on configurable thresholds.
-   **Backup Verification:** Checks all databases on an instance to ensure they meet the backup compliance policy (e.g., a full backup exists within the last 26 hours).
-   **Server Health Checks:** Performs basic health checks, such as identifying failed SQL Agent jobs.
-   **HTML Reporting:** Generates a clean HTML report summarizing the health status of all monitored servers.
-   **Email Notifications:** Automatically emails the HTML report to specified recipients.
-   **Logging:** Creates a detailed log file for troubleshooting and auditing.

## Prerequisites

To use this framework, you will need:
1.  PowerShell 5.1 or later.
2.  The **DBAtools** PowerShell module.

You can install the DBAtools module by running the following command in PowerShell as an administrator:
```powershell
Install-Module -Name DBATools
