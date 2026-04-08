# NATMap 更新脚本 - PowerShell 版本
# 用法: .\update.ps1 -PublicIp "1.2.3.4" -PublicPort 12345 -LocalIp "192.168.1.100"

param(
    [Parameter(Mandatory=$true)]
    [string]$PublicIp,
    
    [Parameter(Mandatory=$true)]
    [int]$PublicPort,
    
    [string]$LocalIp = "192.168.1.100",
    [string]$Protocol = "tcp",
    [int]$LocalPort = 9001
)

$ApiUrl = "https://nm.kszhc.top/api/update"
$ApiKey = "abc123apikey"
$App = "vpn"

$Headers = @{
    "Content-Type" = "application/json"
    "X-API-Key" = $ApiKey
}

$Body = @{
    app = $App
    ip = $PublicIp
    port = $PublicPort
    proto = $Protocol
    local_ip = $LocalIp
    local_port = $LocalPort
} | ConvertTo-Json

try {
    $Response = Invoke-RestMethod -Uri $ApiUrl -Method POST -Headers $Headers -Body $Body
    Write-Output "更新成功: $($Response | ConvertTo-Json)"
} catch {
    Write-Error "更新失败: $_"
}
