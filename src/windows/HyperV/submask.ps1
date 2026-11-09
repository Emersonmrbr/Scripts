function Convert-MaskToPrefix {
  param (
    [string]$Mask
  )
  $bits = $Mask.Split('.') | ForEach-Object {
    [System.Convert]::ToString([byte]$_, 2).PadLeft(8, '0')
  }
  $prefix = ($bits -join '').TrimEnd('0').Length
  return "$prefix"
}

$mascara = Convert-MaskToPrefix -Mask "255.255.255.0"
$mascara

#[Convert]::ToString ([byte]$_, 2).PadLeft (8, '0')

