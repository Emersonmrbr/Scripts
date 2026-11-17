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

# Check if GitHub is reachable and fetch available Oh My Posh themes
if (Test-Connection "api.github.com" -Count 1 -Quiet) {
  # Fetch the list of available Oh My Posh themes from GitHub
  $url = "https://api.github.com/repos/JanDeDobbeleer/oh-my-posh/contents/themes"
  # Set the User-Agent header to avoid GitHub API rate limiting
  $themes = Invoke-RestMethod -Uri $url
  # Extract the theme file names from the GitHub response
  $themeFiles = $themes | Where-Object { $_.name -like "*.omp.json" } | Select-Object -ExpandProperty download_url
}
Else {
  # Initialize a random Oh My Posh theme for the PowerShell session
  $themeFiles = Get-ChildItem -Path "C:\Users\emers\.config\oh-my-posh" | Select-Object -ExpandProperty FullName
}
# Get a random index for the available Oh My Posh themes
$randomThemeIndex = Get-Random -Minimum 0 -Maximum $themeFiles.Count
# Initialize Oh My Posh with the randomly selected theme
oh-my-posh init pwsh --config $themeFiles[$randomThemeIndex] | Invoke-Expression

if ($LASTEXITCODE -ne 0) {
  Write-Status "Error initializing Oh My Posh: $LASTEXITCODE" -Type "ERROR"
}
Else {
  Write-Status "Oh My Posh initialized successfully." -Type "OK"
}


#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58

# LiteLLM gateway terminal helpers (ask, claude-cheap) — versioned in the Docker
# repo; see D:\Repos\Docker\CLAUDE.md "LiteLLM" → "Terminal helpers".
if (Test-Path 'D:\Repos\AURA\clients\aura.profile.ps1') { . 'D:\Repos\AURA\clients\aura.profile.ps1' }

$handler = {
  param([string]$Line)
  if ($Line -match '(?i)password|secret|token|apikey|ConvertTo-SecureString') { return $false }
  return $true
}
Set-PSReadLineOption -AddToHistoryHandler $handler

function Help {
  <#
    .SYNOPSIS
    Gets help information for the available commands in this profile.
    .EXAMPLE
    Help   # Display help information for the available commands in this profile
    #>
  param(
    [switch]$upall,
    [switch]$vmohdd,
    [switch]$vmc,
    [switch]$vmst,
    [switch]$vmsp,
    [switch]$vmca,
    [switch]$clearPc
  )

  if ($upall) {
    Write-Status "upall -Autoreboot" -Type "INFO" 
    Write-Status "upall -Verbose" -Type "INFO"
  }
  elseif ($vmohdd) {
    Write-Status "vmohdd - Compact VHDs of all turned-off Hyper-V VMs" -Type "INFO"
  }
  elseif ($vmc) {
    Write-Status "vmc <Tab>, <Tab>, <Tab>, ... VM -> connect to the VM using vmconnect.exe" -Type "INFO"
  }
  elseif ($vmst) {
    Write-Status "vmst <Tab>, <Tab>, <Tab>, ....  VM -> start the VM and connect to it" -Type "INFO"
  }
  elseif ($vmsp) {
    Write-Status "vmsp <Tab>  VM -> stop the VM (with options to force stop or stop all running VMs)" -Type "INFO"
  }
  elseif ($vmca) {
    Write-Status "vmca <Tab> <Tab> <Tab> VM -> adapter of that VM -> switch" -Type "INFO"
  }
  elseif ($clearPc) {
    Write-Status "clear-pc - Clears temporary files on the local machine, including $env:TEMP and C:\Windows\Temp." -Type "INFO"
  }
  else {
    Write-Status "upall - Updates all system components including winget packages, Microsoft Store apps, and Windows updates." -Type "INFO"
    Write-Status "vmohdd - Compacts the virtual hard disks (VHDs) of all turned-off Hyper-V VMs." -Type "INFO"
    Write-Status "vmc - Connects a Hyper-V VM using vmconnect." -Type "INFO"
    Write-Status "vmst - Starts a Hyper-V VM and connects to it using vmconnect." -Type "INFO"
    Write-Status "vmsp - Stops a running Hyper-V VM, with options to force stop or stop all running VMs." -Type "INFO"
    Write-Status "vmca - Connects a Hyper-V VM network adapter to a virtual switch." -Type "INFO"
    Write-Status "clear-pc - Clears temporary files on the local machine, including $env:TEMP and C:\Windows\Temp." -Type "INFO"
    Write-Status "help - Displays this help information." -Type "INFO"
  }
}

function upall {
  <#
    .SYNOPSIS
    Updates all system components including winget packages, Microsoft Store apps, and Windows updates.
    .EXAMPLE
    upall   # Update all system components
    #>
  param(
    [switch]$Autoreboot,
    [switch]$Verbose
  )

  $params = @()
  if ($Verbose) { $params += "--verbose-logs" }

  winget source update @params

  if ($LASTEXITCODE -ne 0) {
    Write-Status "Error updating winget sources: $LASTEXITCODE" -Type "ERROR"
  }
  else {
    Write-Status "Winget sources updated successfully." -Type "INFO"
  }

  winget upgrade --all --accept-package-agreements --accept-source-agreements --include-unknown @params

  if ($LASTEXITCODE -ne 0) {
    Write-Status "Error updating winget packages: $LASTEXITCODE" -Type "ERROR"
  }
  else {
    Write-Status "Winget packages updated successfully. " -Type "INFO"
  }
  
  microsoftstore updates --apply

  if ($LASTEXITCODE -ne 0) {
    Write-Status "Error updating Microsoft Store apps: $LASTEXITCODE" -Type "ERROR"
  }
  else {
    Write-Status "Microsoft Store apps updated successfully." -Type "INFO"
  }
  
  Get-WindowsUpdate -ComputerName localhost -Install -AcceptAll -ForceInstall -Autoreboot:$Autoreboot -Verbose:$Verbose

  if ($LASTEXITCODE -ne 0) {
    Write-Status "Error updating Windows updates: $LASTEXITCODE" -Type "ERROR"
  }
  else {
    Write-Status "Windows updates installed successfully." -Type "INFO"
  }

}

function vmohdd {
  <#
    .SYNOPSIS
    Compacts the virtual hard disks (VHDs) of all turned-off Hyper-V VMs.
    .EXAMPLE
    vmohdd # Compact VHDs of all turned-off Hyper-V VMs
    #>
  Get-VM | 
  Where-Object State -eq 'Off' |
  ForEach-Object {
    Get-VMHardDiskDrive -VMName $_.Name |
    ForEach-Object {
      try {
        $vhdBefore = Get-VHD -Path $_.Path | Select-Object Path, FileSize, Size
        Write-Status "Before: $($vhdBefore.FileSize) bytes" -Type "INFO"
        Write-Status "Compacting $($_.Path)" -Type "INFO"
        Optimize-VHD -Path $_.Path -Mode Full
        $vhdAfter = Get-VHD -Path $_.Path | Select-Object Path, FileSize, Size
        Write-Status "After: $($vhdAfter.FileSize) bytes" -Type "INFO"
        Write-Status "Saved: $($vhdBefore.FileSize - $vhdAfter.FileSize) bytes" -Type "INFO"
      }
      catch {
        Write-Status "Error compacting VHD $($_.Path): $($_.Exception.Message)" -Type "ERROR"
      }
    }
  }
}

function vmc {
  <#
    .SYNOPSIS
    Connects a Hyper-V VM using vmconnect.
    .EXAMPLE
    vmc <Tab>, <Tab>, <Tab>, ...  # VM -> connect to the VM using vmconnect
    #>
  param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [ArgumentCompleter({
        param($cmd, $param, $word)
        try {
          Get-VM -ErrorAction Stop |
          Where-Object Name -like "$($word.Trim('"', "'"))*" |
          ForEach-Object {
            $n = if ($_.Name -match '\s') { "'$($_.Name)'" } else { $_.Name }
            [System.Management.Automation.CompletionResult]::new($n, $_.Name, 'ParameterValue', $_.State.ToString())
          }
        }
        catch {
          Write-Status "Error completing VM name: $($_.Exception.Message)" -Type "ERROR"
        }
      })]
    [string[]]$Name
  )
  if ($Name) {
    foreach ($n in $Name) {
      Start-Process vmconnect.exe -ArgumentList "localhost `"$n`"" -Verb RunAs
      Write-Status "Connecting to $n..." -Type "INFO"
    }
  }
  else {
    Start-Process vmconnect.exe -Verb RunAs
    Write-Status "Connecting to VM..." -Type "INFO"
  }
}

# Start a VM (vms) and connect to it using vmconnect
function vmst {
  <#
    .SYNOPSIS
    Starts a Hyper-V VM and connects to it using vmconnect.
    .EXAMPLE
    vmst <Tab>, <Tab>, <Tab>, ....      # VM -> start the VM and connect to it
    #>
  param(
    [Parameter(Mandatory, Position = 0, ValueFromRemainingArguments)]
    [ArgumentCompleter({
        param($cmd, $param, $word)
        try {
          Get-VM -ErrorAction Stop |
          Where-Object Name -like "$($word.Trim('"', "'"))*" |
          ForEach-Object {
            $n = if ($_.Name -match '\s') { "'$($_.Name)'" } else { $_.Name }
            [System.Management.Automation.CompletionResult]::new($n, $_.Name, 'ParameterValue', $_.State.ToString())
          }
        }
        catch {
          Write-Status "Error completing VM name: $($_.Exception.Message)" -Type "ERROR"
        }
      })]
    [string[]]$Name
  )
  foreach ($n in $Name) {
    try {
      $vm = Get-VM -Name $n -ErrorAction Stop
      if ($vm.State -ne 'Running') {
        Write-Status "Starting $($vm.Name)..." -Type "INFO"
        Start-VM -VM $vm -ErrorAction Stop
      }
      else {
        Write-Status "$($vm.Name) is already running." -Type "OK"
      }
      vmc $vm.Name
    }
    catch {
      Write-Warning "${n}: $($_.Exception.Message)"
    }
  }
}

# Turn off a VM (vmstop) with options to force or stop all running VMs
function vmsp {
  <#
    .SYNOPSIS
    Stops a running Hyper-V VM, with options to force stop or stop all running VMs.
    .EXAMPLE
    vmsp <Tab>  # VM -> stop the VM (with options to force stop or stop all running VMs)
    #>
  param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [ArgumentCompleter({
        param($cmd, $param, $word)
        try {
          Get-VM -ErrorAction Stop |
          Where-Object { $_.State -ne 'Off' -and $_.Name -like "$($word.Trim('"', "'"))*" } |
          ForEach-Object {
            $n = if ($_.Name -match '\s') { "'$($_.Name)'" } else { $_.Name }
            [System.Management.Automation.CompletionResult]::new($n, $_.Name, 'ParameterValue', $_.State.ToString())
          }
        }
        catch {
          Write-Status "Error completing VM name: $($_.Exception.Message)" -Type "ERROR"
        }
      })]
    [string[]]$Name,
    [switch]$Force,
    [switch]$All
  )
  if ($All) {
    $Name = (Get-VM | Where-Object State -ne 'Off').Name
    if (-not $Name) { Write-Host 'No VMs are running.' -ForegroundColor DarkGray; return }
  }
  elseif (-not $Name) {
    Write-Warning 'Provide the name of the VM(s) or use -All.'; return
  }
  foreach ($n in $Name) {
    try {
      $vm = Get-VM -Name $n -ErrorAction Stop
      if ($vm.State -eq 'Off') {
        Write-Status "$($vm.Name) is already off." -Type "OK"
        continue
      }
      if ($Force) {
        Write-Status "Cutting power to $($vm.Name)..." -Type "WARNING"
        Stop-VM -VM $vm -TurnOff -Force -ErrorAction Stop
      }
      else {
        Write-Status "Shutting down $($vm.Name)..." -Type "INFO"
        Stop-VM -VM $vm -Force -ErrorAction Stop
      }
    }
    catch {
      Write-Warning "${n}: $($_.Exception.Message)"
    }
  }
}

function vmca {
  <#
    .SYNOPSIS
    Connects a Hyper-V VM network adapter to a virtual switch.
    .EXAMPLE
    vmca <Tab> <Tab> <Tab>      # VM -> adapter of that VM -> switch
    #>
  [CmdletBinding()]
  param(
    # VM name(s) - tab completes all Hyper-V VMs
    [Parameter(Mandatory, Position = 0)]
    [ArgumentCompleter({
        param($cmd, $param, $word, $ast, $bound)
        $w = $word.Trim('"', "'")
        Get-VM -ErrorAction SilentlyContinue |
        Where-Object Name -like "$w*" |
        ForEach-Object {
          $n = if ($_.Name -match '\s') { "'$($_.Name)'" } else { $_.Name }
          [System.Management.Automation.CompletionResult]::new($n, $_.Name, 'ParameterValue', "$($_.Name) [$($_.State)]")
        }
      })]
    [string[]]$Name,

    # Adapter name - tab completes adapters of the VM(s) already typed in -Name
    [Parameter(Mandatory, Position = 1)]
    [ArgumentCompleter({
        param($cmd, $param, $word, $ast, $bound)
        if (-not $bound.ContainsKey('Name')) { return }
        $w = $word.Trim('"', "'")
        @($bound['Name']) | ForEach-Object {
          Get-VMNetworkAdapter -VMName $_ -ErrorAction SilentlyContinue
        } | Where-Object Name -like "$w*" |
        Group-Object Name |
        ForEach-Object {
          $a = $_.Group[0]
          $n = if ($a.Name -match '\s') { "'$($a.Name)'" } else { $a.Name }
          $sw = if ($a.SwitchName) { $a.SwitchName } else { '<disconnected>' }
          [System.Management.Automation.CompletionResult]::new($n, $a.Name, 'ParameterValue', "$($a.Name) -> $sw ($($a.MacAddress))")
        }
      })]
    [string]$AdapterName,

    # Switch name - tab completes all virtual switches
    [Parameter(Mandatory, Position = 2)]
    [ArgumentCompleter({
        param($cmd, $param, $word, $ast, $bound)
        $w = $word.Trim('"', "'")
        Get-VMSwitch -ErrorAction SilentlyContinue |
        Where-Object Name -like "$w*" |
        ForEach-Object {
          $n = if ($_.Name -match '\s') { "'$($_.Name)'" } else { $_.Name }
          [System.Management.Automation.CompletionResult]::new($n, $_.Name, 'ParameterValue', "$($_.Name) [$($_.SwitchType)]")
        }
      })]
    [string]$SwitchName,

    # Open vmconnect after connecting the adapter
    [switch]$ConnectConsole
  )

  if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    Write-Status "Switch '$SwitchName' not found." -Type "ERROR"
    return
  }

  foreach ($vmName in $Name) {
    try {
      $vm = Get-VM -Name $vmName -ErrorAction Stop
      $adapters = @(Get-VMNetworkAdapter -VM $vm -Name $AdapterName -ErrorAction Stop)
      if ($adapters.Count -gt 1) {
        Write-Warning "[$($vm.Name)] $($adapters.Count) adapters named '$AdapterName' - all will be connected. Rename them with Rename-VMNetworkAdapter to target one."
      }
      foreach ($adapter in $adapters) {
        if ($adapter.SwitchName -eq $SwitchName) {
          Write-Status "[$($vm.Name)] '$AdapterName' already connected to '$SwitchName'." -Type "OK"
          continue
        }
        $from = if ($adapter.SwitchName) { $adapter.SwitchName } else { '<disconnected>' }
        Write-Status "[$($vm.Name)] '$AdapterName': $from -> $SwitchName" -Type "INFO"
        $adapter | Connect-VMNetworkAdapter -SwitchName $SwitchName -ErrorAction Stop
        Write-Status "[$($vm.Name)] Connected successfully." -Type "OK"
      }
      if ($ConnectConsole) {
        Write-Status "[$($vm.Name)] Launching VM console..." -Type "INFO"
        vmc $vm.Name
      }
    }
    catch {
      $msg = $_.Exception.Message
      if ($msg -like "*access denied*" -or $msg -like "*permission*") {
        Write-Status "[$vmName] Access denied - run PowerShell as Administrator." -Type "ERROR"
      }
      else {
        Write-Warning "[$vmName] $msg"
      }
    }
  }
}

function clear-PC {
  <#
    .SYNOPSIS
    Clears temporary files on the local machine, including $env:TEMP and C:\Windows\Temp.
    .EXAMPLE
    Clear-PC # Clears temporary files on the local machine
    #>
  $startTime = Get-Date
  $toolsPath = "$env:USERPROFILE\Documents\Tools\SDelete"
  $uri = "https://download.sysinternals.com/files/SDelete.zip"
  $zipPath = "$env:TEMP\SDelete.zip"
  $scriptPath = $PSCommandPath
  $driveCBefore = Get-Volume -DriveLetter C
  $driveCTotalBefore = [math]::Round($driveCBefore.Size / 1GB, 2)
  $driveCFreeBefore = [math]::Round($driveCBefore.SizeRemaining / 1GB, 2)
  $driveDBefore = Get-Volume -DriveLetter D
  $driveDTotalBefore = [math]::Round($driveDBefore.Size / 1GB, 2)
  $driveDFreeBefore = [math]::Round($driveDBefore.SizeRemaining / 1GB, 2)
  [PSObject[]]$lpgFault = @( [PSObject]@{ status = $true; exitCode = 0; message = "" } )

  Write-Status -Message "=" -Type "=" -RepeatCount 100
  Write-Status -Message "[INFO] Preparing to clean temporary files" -Type "INFO"
  Write-Status -Message "=" -Type "=" -RepeatCount 100

  Write-Status -Message "[INFO] Disk C: Total = $driveCTotalBefore GB Free = $driveCFreeBefore GB" -Type "INFO"
  Write-Status -Message "[INFO] Disk D: Total = $driveDTotalBefore GB Free = $driveDFreeBefore GB" -Type "INFO"

  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Status "[ERROR] This script must be run as an administrator." -Type "ERROR"
    Write-Status "[INFO] Open a terminal as an administrator and rerun ${scriptPath}" -Type "INFO"
    exit 1
  }


  Remove-Item "$env:TEMP\" -Recurse -Force -ErrorAction SilentlyContinue
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

  # Securely delete free space on the drives using SDelete
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

  $driveCAfter = Get-Volume -DriveLetter C
  $driveCTotalAfter = [math]::Round($driveCAfter.Size / 1GB, 2)
  $driveCFreeAfter = [math]::Round($driveCAfter.SizeRemaining / 1GB, 2)
  $driveDAfter = Get-Volume -DriveLetter D
  $driveDTotalAfter = [math]::Round($driveDAfter.Size / 1GB, 2)
  $driveDFreeAfter = [math]::Round($driveDAfter.SizeRemaining / 1GB, 2)
  $driveCTotalDiff = $driveCTotalAfter - $driveCTotalBefore
  $driveCFreeDiff = $driveCFreeAfter - $driveCFreeBefore
  $driveDTotalDiff = $driveDTotalAfter - $driveDTotalBefore
  $driveDFreeDiff = $driveDFreeAfter - $driveDFreeBefore

  Write-Status -Message "[INFO] Disk C: Total: $driveCTotalAfter GB, Free: $driveCFreeAfter GB, Diff: $driveCTotalDiff GB / $driveCFreeDiff GB" -Type "Info"
  Write-Status -Message "[INFO] Disk D: Total: $driveDTotalAfter GB, Free: $driveDFreeAfter GB, Diff: $driveDTotalDiff GB / $driveDFreeDiff GB" -Type "Info"

  $endTime = Get-Date
  Write-Status -Message "[INFO] Script started at: $startTime" -Type "INFO"
  Write-Status -Message "[INFO] Script ended at: $endTime" -Type "INFO"
  Write-Status -Message "[INFO] Total duration: $($endTime - $startTime)" -Type "INFO"
  Write-Status -Message "=" -Type "=" -RepeatCount 100

}
