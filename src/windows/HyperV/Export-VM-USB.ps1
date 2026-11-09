# Export stopped Hyper-V virtual machines to local 7z archives.

$startTime = Get-Date
$exportPath = "E:\VirtualMachine\HyperV"
$sevenZipPath = "C:\Program Files\7-Zip\7z.exe"
$vms = @(Get-VM TIA17 -ErrorAction Stop)
$failedVMs = @()

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
Write-Status -Message "[INFO] Preparing to export VMs: $($vms.Name -join ', '); " -Type "INFO"
Write-Status -Message "=" -Type "=" -RepeatCount 100

foreach ($vm in $vms | Where-Object State -eq "Off") {
  Write-Status -Message "[INFO] Export VM: $($vm.Name) to $exportPath" -Type "INFO"
}

try {
  if (-not (Test-Path -LiteralPath $sevenZipPath -PathType Leaf)) {
    throw "7-Zip executable not found: $sevenZipPath"
  }

  if (Test-Path -LiteralPath $exportPath -PathType Leaf) {
    throw "Export path exists but is not a directory: $exportPath"
  }

  if (-not (Test-Path -LiteralPath $exportPath -PathType Container)) {
    New-Item -ItemType Directory -Path $exportPath -ErrorAction Stop | Out-Null
  }
}
catch {
  Write-Status -Message "Unable to prepare the export: $($_.Exception.Message)" -Type "ERROR"
  exit 1
}

if (($vms | Where-Object State -eq "Off").Count -eq 0) {
  Write-Status -Message "No stopped virtual machines were found to export." -Type "WARNING"
  exit 0
}

foreach ($vm in $vms | Where-Object State -eq "Off") {
  $vmExportPath = Join-Path $exportPath $vm.Name
  $archivePath = Join-Path $exportPath "$($vm.Name).7z"
  $temporaryArchive = "$archivePath.$([guid]::NewGuid().ToString('N')).tmp"

  Write-Status -Message "Exporting VM '$($vm.Name)'." -Type "INFO"

  try {
    if (Test-Path -LiteralPath $vmExportPath) {
      throw "Export directory already exists; refusing to overwrite it: $vmExportPath"
    }
    if (Test-Path -LiteralPath $archivePath -PathType Container) {
      throw "Archive path already exists as a directory: $archivePath"
    }

    Export-VM -VM $vm -Path $exportPath -ErrorAction Stop | Out-Null
    if (-not (Test-Path -LiteralPath $vmExportPath -PathType Container)) {
      throw "Hyper-V export completed without creating the expected directory: $vmExportPath"
    }
    Write-Status -Message "Exported VM '$($vm.Name)'." -Type "OK"

    $sevenZipOutput = & $sevenZipPath a -t7z -mx=5 $temporaryArchive $vmExportPath 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "7-Zip compression failed with exit code $LASTEXITCODE. $($sevenZipOutput -join ' ')"
    }
    if (-not (Test-Path -LiteralPath $temporaryArchive -PathType Leaf)) {
      throw "7-Zip did not create the expected archive: $temporaryArchive"
    }

    $archiveInfo = Get-Item -LiteralPath $temporaryArchive -ErrorAction Stop
    if ($archiveInfo.Length -eq 0) {
      throw "7-Zip created an empty archive: $temporaryArchive"
    }

    $testOutput = & $sevenZipPath t $temporaryArchive 2>&1
    if ($LASTEXITCODE -ne 0) {
      throw "7-Zip archive verification failed with exit code $LASTEXITCODE. $($testOutput -join ' ')"
    }

    Move-Item -LiteralPath $temporaryArchive -Destination $archivePath -Force -ErrorAction Stop
    Write-Status -Message "Created and verified archive '$archivePath'." -Type "OK"

    Remove-Item -LiteralPath $vmExportPath -Recurse -Force -ErrorAction Stop
    Write-Status -Message "Removed temporary export directory for '$($vm.Name)'." -Type "OK"
  }
  catch {
    $failedVMs += $vm.Name
    Write-Status -Message "Failed to process VM '$($vm.Name)': $($_.Exception.Message)" -Type "ERROR"
    if ($_.ScriptStackTrace) {
      Write-Status -Message $_.ScriptStackTrace -Type "ERROR"
    }

    if (Test-Path -LiteralPath $temporaryArchive -PathType Leaf) {
      try {
        Remove-Item -LiteralPath $temporaryArchive -Force -ErrorAction Stop
      }
      catch {
        Write-Status -Message "Could not remove temporary archive '$temporaryArchive': $($_.Exception.Message)" -Type "WARNING"
      }
    }
  }
}

Write-Status -Message "=" -Type "=" -RepeatCount 100
if ($failedVMs.Count -gt 0) {
  Write-Status -Message "Export completed with failures for: $($failedVMs -join ', ')." -Type "ERROR"
  exit 1
}
else {
  Write-Status -Message "All stopped virtual machines were exported and verified in '$exportPath'." -Type "OK"
}

$endTime = Get-Date
Write-Status -Message "[INFO] Script started at: $startTime" -Type "INFO"
Write-Status -Message "[INFO] Script ended at: $endTime" -Type "INFO"
Write-Status -Message "[INFO] Total duration: $($endTime - $startTime)" -Type "INFO"
Write-Status -Message "=" -Type "=" -RepeatCount 100