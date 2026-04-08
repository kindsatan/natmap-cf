# NATMap API 简化版并发性能测试
# 使用 Start-Job 实现并发，兼容性好

param(
    [string]$Url = "https://nm.kszhc.top/api/get?tenant_id=3&app_id=3",
    [int]$Concurrent = 10,
    [int]$Requests = 100
)

Write-Host "NATMap API 并发测试" -ForegroundColor Cyan
Write-Host "URL: $Url" -ForegroundColor Yellow
Write-Host "并发: $Concurrent, 总请求: $Requests" -ForegroundColor Yellow
Write-Host ""

# 测试单个请求
function Test-Request {
    param([int]$Id)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod -Uri $Url -TimeoutSec 30
        $sw.Stop()
        $cache = if ($resp._cache -eq "HIT") { "HIT" } else { "MISS" }
        return @{ Id=$Id; Latency=$sw.ElapsedMilliseconds; Cache=$cache; Success=$true }
    }
    catch {
        $sw.Stop()
        return @{ Id=$Id; Latency=$sw.ElapsedMilliseconds; Cache="ERR"; Success=$false }
    }
}

# 执行测试
$start = Get-Date
$jobs = @()

for ($i = 1; $i -le $Requests; $i++) {
    $jobs += Start-Job -ScriptBlock ${function:Test-Request} -ArgumentList $i
    
    # 控制并发数
    while ((Get-Job -State Running).Count -ge $Concurrent) {
        Start-Sleep -Milliseconds 50
    }
    
    if ($i % 10 -eq 0) { Write-Host "." -NoNewline -ForegroundColor Cyan }
}

Write-Host "`n等待完成..." -ForegroundColor Yellow
$results = $jobs | Wait-Job | Receive-Job
Remove-Job *

$duration = ((Get-Date) - $start).TotalSeconds

# 统计
$success = $results | Where-Object { $_.Success }
$latencies = $success | ForEach-Object { $_.Latency } | Sort-Object
$hits = ($results | Where-Object { $_.Cache -eq "HIT" }).Count

Write-Host "`n========== 测试结果 ==========" -ForegroundColor Cyan
Write-Host "总请求: $Requests"
Write-Host "成功: $($success.Count)"
Write-Host "失败: $($Requests - $success.Count)"
Write-Host "缓存命中: $hits ($([math]::Round($hits/$Requests*100,1))%)"
Write-Host "总耗时: $([math]::Round($duration,2)) 秒"
Write-Host "RPS: $([math]::Round($Requests/$duration,1))"
Write-Host ""
Write-Host "延迟统计 (ms):" -ForegroundColor Yellow
Write-Host "  平均: $([math]::Round(($latencies | Measure-Object -Average).Average,1))"
Write-Host "  最小: $($latencies | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum)"
Write-Host "  最大: $($latencies | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)"
Write-Host "  P50: $($latencies[[int]($latencies.Count*0.5)])"
Write-Host "  P90: $($latencies[[int]($latencies.Count*0.9)])"
Write-Host "  P99: $($latencies[[int]($latencies.Count*0.99)])"
