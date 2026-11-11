# Script to export all Hyper-V virtual machines to a local path and then copy them to a network destination using robocopy

# Define the local export path and the network destination path
$exportPath = "D:\VMExports"
if (-not (Test-Path $exportPath)) {
  New-Item -ItemType Directory -Path $exportPath | Out-Null
}
$destinationPath = "\\NAS-NucleoMAP\Nextcloud1\VirtualMachine\HyperV"

function Write-Status {
  param(
    [string]$Message,
    [string]$Type = "INFO"
  )

  $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

  switch ($Type.ToUpper()) {
    "INFO" { Write-Host "[$TimeStamp] $Message" -ForegroundColor Cyan }
    "OK" { Write-Host "[$TimeStamp] $Message" -ForegroundColor Green }
    "ERROR" { Write-Host "[$TimeStamp] $Message" -ForegroundColor Red }
    default { Write-Host "[$TimeStamp] $Message" }
  }
}

$vms = Get-VM
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
    Remove-Item -Path $vmSource -Recurse -Force
    Write-Status -Message "[OK] Removed local export: $vmSource" -Type "OK"
  }
  else {
    Write-Status -Message "[ERROR] Robocopy failed with exit code $LASTEXITCODE" -Type "ERROR"
    break
  }

}

Write-Status -Message "[OK] All virtual machines have been exported and copied to the destination." -Type "OK"