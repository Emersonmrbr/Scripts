Clear-Host
# Define the range of IP addresses
$ipRange = 1..10 | ForEach-Object {"192.168.18.$_"}

# Array to store reachable IPs
$reachableIPs = @()

# Loop through each IP address and test the connection
foreach ($ip in $ipRange) {
    if (Test-Connection -ComputerName $ip -Count 1 -Quiet) {
        $reachableIPs += $ip
        Write-Host "$ip is reachable"
    } else {
        Write-Host "$ip is not reachable"
    }
}
Write-Host "-----------done-------"

# Output the reachable IPs

Write-Host ""
Write-Host "------------------------"
$reachableIPs
Write-Host "------------------------"

#$ping = New-Object System.Net.Networkinformation.Ping
#1..10 | % { $ping.send("192.168.18.$_") | select address, status }