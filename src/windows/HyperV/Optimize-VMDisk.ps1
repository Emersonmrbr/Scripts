Get-VM | Where-Object State -eq 'Off' |
ForEach-Object {
  Get-VMHardDiskDrive -VMName $_.Name |
  ForEach-Object {
    $vhdBefore = Get-VHD -Path $_.Path | Select-Object Path, FileSize, Size
    Write-Host "Before: $($vhdBefore.FileSize) bytes"
    Write-Host "Compacting $($_.Path)"
    Optimize-VHD -Path $_.Path -Mode Full
    $vhdAfter = Get-VHD -Path $_.Path | Select-Object Path, FileSize, Size
    Write-Host "After: $($vhdAfter.FileSize) bytes"
    Write-Host "Saved: $($vhdBefore.FileSize - $vhdAfter.FileSize) bytes"
  }
}