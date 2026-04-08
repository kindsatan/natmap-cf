# NATMap 查询脚本 - PowerShell 版本
# 用法: .\get.ps1

$ApiUrl = "https://nm.kszhc.top/api/get?tenant=companyA&app=vpn"

try {
    $Response = Invoke-RestMethod -Uri $ApiUrl -Method GET
    
    Write-Output "公网地址: $($Response.public_ip):$($Response.public_port)"
    Write-Output "更新时间: $($Response.updated_at)"
} catch {
    Write-Error "查询失败: $_"
}
