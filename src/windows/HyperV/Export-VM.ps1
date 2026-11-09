# Script to export all Hyper-V virtual machines to a local path and then copy them to a network destination using robocopy

# Define the local export path and the network destination path
$startTime = Get-Date
$exportPath = "D:\VMExports"
$vms = @(Get-VM TIA17 -ErrorAction Stop)
if (-not (Test-Path $exportPath)) {
  New-Item -ItemType Directory -Path $exportPath | Out-Null
}
$destinationPath = "\\NAS-NucleoMAP\Nextcloud1\VirtualMachine\HyperV"

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
    "=" { Write-Host ( "$Message" * $RepeatCount) -ForegroundColor Cyan -NoNewLine:$NoNewLine }
    default { Write-Host "[$TimeStamp] $Message" -NoNewLine:$NoNewLine }
  }
}

Write-Status -Message "=" -Type "=" -RepeatCount 100
Write-Status -Message "[INFO] Preparing to export VMs: $($vms.Name -join ', '); " -Type "INFO"
Write-Status -Message "=" -Type "=" -RepeatCount 100

foreach ($vm in $vms | Where-Object State -eq "Off") {
  Write-Status -Message "[INFO] Exporting VM: $($vm.Name)" -Type "INFO"
  try {    
    Export-VM -VM $vm -Path $exportPath -ErrorAction Stop
    Write-Status -Message "[OK] Exported VM: $($vm.Name)" -Type "OK"
  }
  catch {
    Write-Status -Message "[ERROR] Failed to export VM: $($vm.Name). $_" -Type "ERROR"
    continue
  }

  # Define the source and destination paths for the current VM export
  $vmSource = Join-Path $exportPath $vm.Name
  $vmDestination = Join-Path $destinationPath $vm.Name

  robocopy $vmSource $vmDestination /E /MT:32 /J /R:3 /W:5
  
  if ($LASTEXITCODE -le 7) {
    Write-Status -Message "[OK] Copied VM: $($vm.Name) to $vmDestination" -Type "OK" 
    Write-Status -Message "[OK] Robocopy completed successfully with exit code $LASTEXITCODE" -Type "OK"
    if (Test-Path $vmSource) {
      Remove-Item -Path $vmSource -Recurse -Force
      Write-Status -Message "[OK] Removed local export: $vmSource" -Type "OK"
    }
  }
  else {
    Write-Status -Message "[ERROR] Robocopy failed with exit code $LASTEXITCODE" -Type "ERROR"
    break
  }
}

$existingVMs = @(
  $vms | Where-Object {
    Test-Path (Join-Path $destinationPath $_.Name)
  }
)

Write-Status -Message "=" -Type "=" -RepeatCount 100

if ($existingVMs.Count -eq $vms.Count) {
  Write-Status -Message "[INFO] Found $($existingVMs.Count) of $($vms.Count) VMs in destination." -Type "INFO"
  Write-Status -Message "[OK] All VMs were copied." -Type "OK"
}
else {
  Write-Status -Message "[ERROR] Some VMs are missing." -Type "ERROR"

  $missingVMs = $vms | Where-Object {
    -not (Test-Path (Join-Path $destinationPath $_.Name))
  }

  $missingVMs | ForEach-Object {
    Write-Status -Message "[ERROR] Missing VM: $($_.Name)" -Type "ERROR"
  }
}

$endTime = Get-Date
Write-Status -Message "[INFO] Script started at: $startTime" -Type "INFO"
Write-Status -Message "[INFO] Script ended at: $endTime" -Type "INFO"
Write-Status -Message "[INFO] Total duration: $($endTime - $startTime)" -Type "INFO"
Write-Status -Message "=" -Type "=" -RepeatCount 100
