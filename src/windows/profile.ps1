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
  $themeFiles = Get-ChildItem -Path "$env:USERPROFILE\.config\oh-my-posh" | Select-Object -ExpandProperty FullName
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
    Write-Status -Message "upall -Autoreboot" -Type "INFO" 
    Write-Status -Message "upall -Verbose" -Type "INFO"
  }
  elseif ($vmohdd) {
    Write-Status -Message "vmohdd - Compact VHDs of all turned-off Hyper-V VMs" -Type "INFO"
  }
  elseif ($vmc) {
    Write-Status -Message "vmc <Tab>, <Tab>, <Tab>, ... VM -> connect to the VM using vmconnect.exe" -Type "INFO"
  }
  elseif ($vmst) {
    Write-Status -Message "vmst <Tab>, <Tab>, <Tab>, ....  VM -> start the VM and connect to it" -Type "INFO"
  }
  elseif ($vmsp) {
    Write-Status -Message "vmsp <Tab>  VM -> stop the VM (with options to force stop or stop all running VMs)" -Type "INFO"
  }
  elseif ($vmca) {
    Write-Status -Message "vmca <Tab> <Tab> <Tab> VM -> adapter of that VM -> switch" -Type "INFO"
  }
  elseif ($clearPc) {
    Write-Status -Message "clear-pc - Clears temporary files on the local machine, including $env:TEMP and C:\Windows\Temp." -Type "INFO"
  }
  else {
    Write-Status -Message "upall - Updates all system components including winget packages, Microsoft Store apps, and Windows updates." -Type "INFO"
    Write-Status -Message "vmohdd - Compacts the virtual hard disks (VHDs) of all turned-off Hyper-V VMs." -Type "INFO"
    Write-Status -Message "vmc - Connects a Hyper-V VM using vmconnect." -Type "INFO"
    Write-Status -Message "vmst - Starts a Hyper-V VM and connects to it using vmconnect." -Type "INFO"
    Write-Status -Message "vmsp - Stops a running Hyper-V VM, with options to force stop or stop all running VMs." -Type "INFO"
    Write-Status -Message "vmca - Connects a Hyper-V VM network adapter to a virtual switch." -Type "INFO"
    Write-Status -Message "clear-pc - Clears temporary files on the local machine, including $env:TEMP and C:\Windows\Temp." -Type "INFO"
    Write-Status -Message "help - Displays this help information." -Type "INFO"
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
    [switch]$WingetUpdate,
    [switch]$MicrosoftStoreUpdates,
    [switch]$WindowsUpdates,
    [switch]$Autoreboot,
    [switch]$Verbose
  )

  $params = @()
  if ($Verbose) { $params += "--verbose-logs" }

  if ($wingetUpdate) {

    winget source update @params

    if ($LASTEXITCODE -ne 0) {
      Write-Status -Message "Error updating winget sources: $LASTEXITCODE" -Type "ERROR"
    }
    else {
      Write-Status -Message "Winget sources updated successfully." -Type "INFO"
    }

    winget upgrade --all --accept-package-agreements --accept-source-agreements --include-unknown @params

    if ($LASTEXITCODE -ne 0) {
      Write-Status -Message "Error updating winget packages: $LASTEXITCODE" -Type "ERROR"
    }
    else {
      Write-Status -Message "Winget packages updated successfully. " -Type "INFO"
    }
  }
  
  if ($MicrosoftStoreUpdates) {

    microsoftstore updates --apply

    if ($LASTEXITCODE -ne 0) {
      Write-Status -Message "Error updating Microsoft Store apps: $LASTEXITCODE" -Type "ERROR"
    }
    else {
      Write-Status -Message "Microsoft Store apps updated successfully." -Type "INFO"
    }
  }

  if ($WindowsUpdates) {
    Get-WindowsUpdate -ComputerName localhost -Install -AcceptAll -ForceInstall -Autoreboot:$Autoreboot -Verbose:$Verbose

    if ($LASTEXITCODE -ne 0) {
      Write-Status -Message "Error updating Windows updates: $LASTEXITCODE" -Type "ERROR"
    }
    else {
      Write-Status -Message "Windows updates installed successfully." -Type "INFO"
    }
  }

  if (-not $WingetUpdate -and -not $MicrosoftStoreUpdates -and -not $WindowsUpdates) {
    Write-Status -Message "No update options specified." -Type "WARNING"
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
        if ($vhdBefore.Size -ne 0) {
          Write-Status -Message "Before: $([math]::Round($vhdBefore.FileSize / 1GB, 4)) GB" -Type "INFO"
        }
        else {
          Write-Status -Message "Before: $vhdBefore.FileSize" -Type "INFO"
        }
        Write-Status -Message "Compacting $($_.Path)" -Type "INFO"
        Optimize-VHD -Path $_.Path -Mode Full
        $vhdAfter = Get-VHD -Path $_.Path | Select-Object Path, FileSize, Size
        if ($vhdAfter.Size -ne 0) {
          Write-Status -Message "After: $([math]::Round($vhdAfter.FileSize / 1GB, 4)) GB" -Type "INFO"
        }
        else {
          Write-Status -Message "After: $vhdAfter.FileSize" -Type "INFO"
        }
        if ($vhdBefore.Size -ne 0 -and $vhdAfter.Size -ne 0) {
          Write-Status -Message "Saved: $([math]::Round(($vhdBefore.FileSize - $vhdAfter.FileSize) / 1GB, 4)) GB" -Type "INFO"
        }
        else {
          Write-Status -Message "Saved: $([math]::Round(($vhdBefore.FileSize - $vhdAfter.FileSize) , 4)) GB" -Type "INFO"
        }
      }
      catch {
        Write-Status -Message "Error compacting VHD $($_.Path): $($_.Exception.Message)" -Type "ERROR"
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
          Write-Status -Message "Error completing VM name: $($_.Exception.Message)" -Type "ERROR"
        }
      })]
    [string[]]$Name
  )
  if ($Name) {
    foreach ($n in $Name) {
      Start-Process vmconnect.exe -ArgumentList "localhost `"$n`"" -Verb RunAs
      Write-Status -Message "Connecting to $n..." -Type "INFO"
    }
  }
  else {
    Start-Process vmconnect.exe -Verb RunAs
    Write-Status -Message "Connecting to VM..." -Type "INFO"
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
          Write-Status -Message "Error completing VM name: $($_.Exception.Message)" -Type "ERROR"
        }
      })]
    [string[]]$Name
  )
  foreach ($n in $Name) {
    try {
      $vm = Get-VM -Name $n -ErrorAction Stop
      if ($vm.State -ne 'Running') {
        Write-Status -Message "Starting $($vm.Name)..." -Type "INFO"
        Start-VM -VM $vm -ErrorAction Stop
      }
      else {
        Write-Status -Message "$($vm.Name) is already running." -Type "OK"
      }
      vmc $vm.Name
    }
    catch {
      Write-Status -Message "${n}: $($_.Exception.Message)" -Type "ERROR"
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
          Write-Status -Message "Error completing VM name: $($_.Exception.Message)" -Type "ERROR"
        }
      })]
    [string[]]$Name,
    [switch]$Force,
    [switch]$All
  )
  if ($All) {
    $Name = (Get-VM | Where-Object State -ne 'Off').Name
    if (-not $Name) { Write-Status -Message 'No VMs are running.' -Type "INFO"; return }
  }
  elseif (-not $Name) {
    Write-Status -Message 'Provide the name of the VM(s) or use -All.' -Type "WARNING"; return
  }
  foreach ($n in $Name) {
    try {
      $vm = Get-VM -Name $n -ErrorAction Stop
      if ($vm.State -eq 'Off') {
        Write-Status -Message "$($vm.Name) is already off." -Type "OK"
        continue
      }
      if ($Force) {
        Write-Status -Message "Cutting power to $($vm.Name)..." -Type "WARNING"
        Stop-VM -VM $vm -TurnOff -Force -ErrorAction Stop
      }
      else {
        Write-Status -Message "Shutting down $($vm.Name)..." -Type "INFO"
        Stop-VM -VM $vm -Force -ErrorAction Stop
      }
    }
    catch {
      Write-Status -Message "${n}: $($_.Exception.Message)" -Type "ERROR"
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
          Write-Status -Message "[$($vm.Name)] '$AdapterName' already connected to '$SwitchName'." -Type "OK"
          continue
        }
        $from = if ($adapter.SwitchName) { $adapter.SwitchName } else { '<disconnected>' }
        Write-Status -Message "[$($vm.Name)] '$AdapterName': $from -> $SwitchName" -Type "INFO"
        $adapter | Connect-VMNetworkAdapter -SwitchName $SwitchName -ErrorAction Stop
        Write-Status -Message "[$($vm.Name)] Connected successfully." -Type "OK"
      }
      if ($ConnectConsole) {
        Write-Status -Message "[$($vm.Name)] Launching VM console..." -Type "INFO"
        vmc $vm.Name
      }
    }
    catch {
      $msg = $_.Exception.Message
      if ($msg -like "*access denied*" -or $msg -like "*permission*") {
        Write-Status -Message "[$vmName] Access denied - run PowerShell as Administrator." -Type "ERROR"
      }
      else {
        Write-Status -Message "[$vmName] $msg" -Type "WARNING"
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
  & "D:\Repos\scripts\src\windows\Clean-PC.ps1"

}

function Home {
  <#
    .SYNOPSIS
    Sets the power plan to the home-specific configuration.
    .EXAMPLE
    Home # Sets the power plan to the home-specific configuration
  #>
  & powercfg /SETACTIVE 196c5dd9-3699-47e9-a81c-b75f5631d40e
  $actualScheme = (powercfg /GETACTIVESCHEME)
  Write-Status -Message "Current power scheme: $actualScheme" -Type "INFO"
}


function Industry {
  <#
    .SYNOPSIS
    Sets the power plan to the industry-specific configuration.
    .EXAMPLE
    Industry # Sets the power plan to the industry-specific configuration
  #>
  & powercfg /SETACTIVE 565cb0d5-0a34-4903-9e13-e8c38c4bab4b
  $actualScheme = (powercfg /GETACTIVESCHEME)
  Write-Status -Message "Current power scheme: $actualScheme" -Type "INFO"
}

