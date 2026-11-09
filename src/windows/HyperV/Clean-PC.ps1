$startTime = Get-Date
$toolsPath = "$env:USERPROFILE\Documents\Tools\SDelete"
$uri = "https://download.sysinternals.com/files/SDelete.zip"
$zipPath = "$env:TEMP\SDelete.zip"
$scriptPath = $PSCommandPath
[PSObject[]]$lpgFault = @( [PSObject]@{ status = $true; exitCode = 0; message = "" } )

function Write-Status {
  param(
    [string]$Message,
    [string]$Type = "INFO",
    [bool]$NoNewLine = $false,
    [int]$RepeatCount = 70
  )

  $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

  switch ($Type.ToUpper()) {
    "INFO" { Write-Host "[$TimeStamp] $Message" -ForegroundColor Cyan -NoNewLine:$NoNewLine }
    "OK" { Write-Host "[$TimeStamp] $Message" -ForegroundColor Green -NoNewLine:$NoNewLine }
    "ERROR" { Write-Host "[$TimeStamp] $Message" -ForegroundColor Red -NoNewLine:$NoNewLine }
    "WARNING" { Write-Host "[$TimeStamp] $Message" -ForegroundColor Yellow -NoNewLine:$NoNewLine }
    "=" { Write-Host ( "$Message" * $RepeatCount) -ForegroundColor Cyan -NoNewLine:$NoNewLine }
    default { Write-Host "[$TimeStamp] $Message" -NoNewLine:$NoNewLine }
  }
}

Write-Status -Message "=" -Type "=" -RepeatCount 100
Write-Status -Message "[INFO] Preparing to clean temporary files" -Type "INFO"
Write-Status -Message "=" -Type "=" -RepeatCount 100

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Status "[ERROR] This script must be run as an administrator." -Type "ERROR"
  Write-Status "[INFO] Open a terminal as an administrator and rerun ${scriptPath}" -Type "INFO"
  exit 1
}

If (-Not (Test-Path $toolsPath)) {
  New-Item -ItemType Directory -Path $toolsPath -Force | Out-Null
}
# Download and extract SDelete for secure file deletion
Write-Status "[INFO] Downloading in $env:TEMP and extracting SDelete to $toolsPath for secure file deletion" -Type "INFO"
try {
  Invoke-WebRequest -Uri $uri -OutFile $zipPath -ErrorAction Stop
}
catch {
  Write-Status "[ERROR] Failed to download or extract SDelete: $_" -Type "ERROR"
  exit 1
}

if (-not (Test-Path $toolsPath\sdelete64.exe -PathType Leaf -ErrorAction Stop)) {
  try {
    Expand-Archive -Path $zipPath -DestinationPath $toolsPath -ErrorAction Stop
  }
  catch {
    Write-Status "[ERROR] Failed to extract SDelete: $_" -Type "ERROR"
    exit 1
  }
}

if (-not (Test-Path $toolsPath\sdelete64.exe -PathType Leaf -ErrorAction Stop)) {
  Write-Status "[ERROR] SDelete tools executable not found: $toolsPath\sdelete64.exe" -Type "ERROR"
  exit 1
}

Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
if ($?) {
  Write-Status "[OK] Successfully cleared temporary files in $env:TEMP" -Type "OK"
  $lpgFault += @( [PSObject]@{ status = $true; exitCode = 0; message = "Successfully cleared temporary files in $env:TEMP" } )
}
else {
  Write-Status "[WARNING] Failed to clear temporary files in $env:TEMP" -Type "Warning"
  $lpgFault += @( [PSObject]@{ status = $false; message = "Failed to clear temporary files in $env:TEMP" } )
}
Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
if ($?) {
  Write-Status "[OK] Successfully cleared temporary files in C:\Windows\Temp" -Type "OK"
  $lpgFault += @( [PSObject]@{ status = $true; exitCode = 0; message = "Successfully cleared temporary files in C:\Windows\Temp" } )
}
else {
  Write-Status "[WARNING] Failed to clear temporary files in C:\Windows\Temp" -Type "Warning"
  $lpgFault += @( [PSObject]@{ status = $false; message = "Failed to clear temporary files in C:\Windows\Temp" } )
}


# Clean up Windows component store
Write-Status "[INFO] Cleaning up Windows component store" -Type "INFO"
Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase
if ($LASTEXITCODE -ne 0) {
  Write-Status "[WARNING] Failed to clean up Windows component store" -Type "Warning"
  $lpgFault += @( [PSObject]@{ status = $false; exitCode = $LASTEXITCODE; message = "Failed to clean up Windows component store" } )
}
else {
  Write-Status "[OK] Windows component store cleanup completed" -Type "OK"
  $lpgFault += @( [PSObject]@{ status = $true; exitCode = 0; message = "Windows component store cleanup completed" } )
}


# Configure and run Disk Cleanup
Write-Status "[INFO] Running Disk Cleanup" -Type "INFO"
cleanmgr /sagerun:1
if ($LASTEXITCODE -ne 0) {
  Write-Status "[WARNING] Failed to run Disk Cleanup" -Type "Warning"
  $lpgFault += @( [PSObject]@{ status = $false; exitCode = $LASTEXITCODE; message = "Failed to run Disk Cleanup" } )
}
else {
  $lpgFault += @( [PSObject]@{ status = $true; exitCode = 0; message = "Disk Cleanup completed" } )
  Write-Status "[OK] Disk Cleanup completed" -Type "OK"
}

# Clear the Recycle Bin
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
if (-not $?) {
  Write-Status "[WARNING] Failed to clear the Recycle Bin" -Type "Warning"
  $lpgFault += @( [PSObject]@{ status = $false; message = "Failed to clear the Recycle Bin" } )
}
else {
  Write-Status "[OK] Recycle Bin cleared" -Type "OK"
  $lpgFault += @( [PSObject]@{ status = $true; exitCode = 0; message = "Recycle Bin cleared" } )
}

# Securely delete free space on the C: drive using SDelete
& "$toolsPath\sdelete64.exe" -z C:
if ($LASTEXITCODE -ne 0) {
  Write-Status "[ERROR] Failed to securely delete free space on the C: drive using SDelete" -Type "Error"
  exit 1
}
Write-Status "[OK] Securely deleting free space on the C: drive using SDelete" -Type "OK"
if (Test-Path "D:\") {
  # Securely delete free space on the D: drive using SDelete only if it exists
  & "$toolsPath\sdelete64.exe" -z D:
  if ($LASTEXITCODE -ne 0) {
    Write-Status "[ERROR] Failed to securely delete free space on the D: drive using SDelete" -Type "Error"
    exit 1
  }
  Write-Status "[OK] Securely deleting free space on the D: drive using SDelete" -Type "OK"
}

if ($lpgFault | Where-Object { $_.status -eq $false }) {
  Write-Status "[WARNING] Failed to execute one or more cleanup operations" -Type "Warning"
}
else {
  Write-Status "[INFO] Script finished, check reported errors." -Type "Info"
}

$endTime = Get-Date
Write-Status -Message "[INFO] Script started at: $startTime" -Type "INFO"
Write-Status -Message "[INFO] Script ended at: $endTime" -Type "INFO"
Write-Status -Message "[INFO] Total duration: $($endTime - $startTime)" -Type "INFO"
Write-Status -Message "=" -Type "=" -RepeatCount 100