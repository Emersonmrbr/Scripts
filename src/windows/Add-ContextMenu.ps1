$LogPath = "C:\Windows\Temp\SystemInstall.log"
Start-Transcript -Path $LogPath -Append

Write-Host "--- [SYSTEM] Starting Infrastructure Installation Sequence ---"

# ==============================================================================
# 1. CONTEXT MENU INSTALLATION

# ==============================================================================

Write-Host " -> [1/1] Stage 1: Basic context menu..."

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


Write-Host "--- System Installation Sequence Completed ---"
Stop-Transcript