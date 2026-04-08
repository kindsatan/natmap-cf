# NATMap 客户端连接脚本 - PowerShell 版本
# 用法: .\connect.ps1

$ApiUrl = "https://nm.kszhc.top/api/get?tenant=companyA&app=vpn"

Write-Output "正在获取最新的公网地址..."

try {
    $Response = Invoke-RestMethod -Uri $ApiUrl -Method GET
    
    $IP = $Response.public_ip
    $Port = $Response.public_port
    
    Write-Output "连接到: $IP`:$Port"
    
    # 尝试使用 PowerShell 的 TCP 客户端连接
    try {
        $Client = New-Object System.Net.Sockets.TcpClient
        $Client.Connect($IP, $Port)
        $Stream = $Client.GetStream()
        $Reader = New-Object System.IO.StreamReader($Stream)
        $Writer = New-Object System.IO.StreamWriter($Stream)
        $Writer.AutoFlush = $true
        
        Write-Output "连接成功！输入 'exit' 退出。"
        
        # 简单的交互式连接
        while ($Client.Connected) {
            if ($Stream.DataAvailable) {
                $Data = $Reader.ReadLine()
                Write-Output "接收: $Data"
            }
            
            if ([Console]::KeyAvailable) {
                $Key = [Console]::ReadKey($true)
                if ($Key.Key -eq [ConsoleKey]::Escape) {
                    break
                }
            }
        }
        
        $Reader.Close()
        $Writer.Close()
        $Client.Close()
    } catch {
        Write-Error "连接失败: $_"
    }
} catch {
    Write-Error "获取地址失败: $_"
}
