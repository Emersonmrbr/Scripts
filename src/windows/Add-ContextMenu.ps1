$LogPath = "C:\Windows\Temp\SystemInstall.log"

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

Start-Transcript -Path $LogPath -Append

Write-Status -Message "[INFO] [SYSTEM] Starting Infrastructure Installation Sequence" -Type "INFO"

# ==============================================================================
# CONTEXT MENU INSTALLATION

# ==============================================================================

Write-Status -Message "[INFO] Basic context menu" -Type "INFO"

# ================================
#  Add Network Tools to Context Menu
#  Author: Emerson
# ================================

Write-Host "Adding network shortcuts to the context menu..." -ForegroundColor Cyan

function Add-ContextMenuItem {
  param(
    [string]$KeyPath,
    [string]$DisplayName,
    [string]$Command,
    [string]$Icon
  )

  New-Item -Path $KeyPath -Force | Out-Null
  Set-ItemProperty -Path $KeyPath -Name "(Default)" -Value $DisplayName -Force

  if ($Icon) {
    Set-ItemProperty -Path $KeyPath -Name "Icon" -Value $Icon -Force
  }

  $cmdPath = "$KeyPath\command"
  New-Item -Path $cmdPath -Force | Out-Null
  Set-ItemProperty -Path $cmdPath -Name "(Default)" -Value $Command -Force
}

$Base = "HKCU:\Software\Classes\Directory\Background\shell"

Add-ContextMenuItem `
  -KeyPath "$Base\NetworkAndSharing" `
  -DisplayName "Network and Sharing" `
  -Command "Control.exe /name Microsoft.networkandSharingcenter" `
  -Icon "C:\Windows\System32\imageres.dll,69"

Add-ContextMenuItem `
  -KeyPath "$Base\NetworkList" `
  -DisplayName "Network List" `
  -Command "cmd.exe /c netstat -a & pause" `
  -Icon "C:\Windows\System32\shell32.dll,17"

Add-ContextMenuItem `
  -KeyPath "$Base\NetworkSettings" `
  -DisplayName "Network Settings" `
  -Command "control netconnections" `
  -Icon "C:\Windows\System32\shell32.dll,18"

Write-Host "Shortcuts successfully added!" -ForegroundColor Green


Write-Status -Message "[OK] System Installation Sequence Completed" -Type "OK"
Stop-Transcript