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

function vmc {
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
                        Write-Status "Completing $($_.Name)..." -Type "INFO"
                    }
                }
                catch {
                    Write-Status "Error completing VM name: $($_.Exception.Message)" -Type "ERROR"
                }
            })]
        [string[]]$Nome
    )
    if ($Nome) {
        foreach ($n in $Nome) {
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
function vms {
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
        [string[]]$Nome
    )
    foreach ($n in $Nome) {
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
function vmstop {
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
        [string[]]$Nome,
        [switch]$Forcar,
        [switch]$Todas
    )
    if ($Todas) {
        $Nome = (Get-VM | Where-Object State -ne 'Off').Name
        if (-not $Nome) { Write-Host 'Nenhuma VM ligada.' -ForegroundColor DarkGray; return }
    }
    elseif (-not $Nome) {
        Write-Warning 'Informe o nome da(s) VM(s) ou use -Todas.'; return
    }
    foreach ($n in $Nome) {
        try {
            $vm = Get-VM -Name $n -ErrorAction Stop
            if ($vm.State -eq 'Off') {
                Write-Status "$($vm.Name) is already off." -Type "OK"
                continue
            }
            if ($Forcar) {
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