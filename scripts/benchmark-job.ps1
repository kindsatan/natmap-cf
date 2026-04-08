# NATMap API 并发性能测试 - 使用 Start-Job
# 兼容 PowerShell 5.1 和 7.x

param(
    [string]$BaseUrl = "https://nm.kszhc.top",
    [int]$TenantId = 3,
    [int]$AppId = 3,
    [int]$Concurrent = 10,
    [int]$Total = 100
)

$Url = "${BaseUrl}/api/get?tenant_id=${TenantId}&app_id=${AppId}"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NATMap API Performance Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "URL: $Url" -ForegroundColor Yellow
Write-Host "Concurrent: $Concurrent, Total: $Total" -ForegroundColor Yellow
Write-Host ""

# 定义测试脚本块
$TestScript = {
    param($Id, $TestUrl)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod -Uri $TestUrl -TimeoutSec 30
        $sw.Stop()
        $cache = if ($resp._cache -eq "HIT") { "HIT" } else { "MISS" }
        return "OK|$Id|$($sw.ElapsedMilliseconds)|$cache"
    }
    catch {
        $sw.Stop()
        return "ERR|$Id|$($sw.ElapsedMilliseconds)|$($_.Exception.Message)"
    }
}

$start = Get-Date
$jobs = @()
$completed = 0

Write-Host "Running tests..." -ForegroundColor Yellow

# 提交所有任务
for ($i = 1; $i -le $Total; $i++) {
    $jobs += Start-Job -ScriptBlock $TestScript -ArgumentList $i, $Url
    
    # 控制并发数
    while ((Get-Job -State Running).Count -ge $Concurrent) {
        Start-Sleep -Milliseconds 10
    }
}

# 等待所有任务完成并收集结果
$results = @()
while ($jobs.Count -gt 0) {
    $completedJobs = $jobs | Where-Object { $_.State -ne 'Running' }
    foreach ($job in $completedJobs) {
        $output = Receive-Job -Job $job
        $parts = $output -split '\|'
        $results += @{
            Id = [int]$parts[1]
            Success = $parts[0] -eq "OK"
            Latency = [int]$parts[2]
            Cache = if ($parts[0] -eq "OK") { $parts[3] } else { "ERR" }
        }
        Remove-Job -Job $job
        $jobs = $jobs | Where-Object { $_ -ne $job }
        $completed++
    }
    
    if ($completed % 10 -eq 0) {
        Write-Host "." -NoNewline -ForegroundColor Cyan
    }
    Start-Sleep -Milliseconds 50
}

$duration = ((Get-Date) - $start).TotalSeconds

Write-Host ""
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 统计
$ok = $results | Where-Object { $_.Success }
$latencies = $ok | ForEach-Object { $_.Latency } | Sort-Object
$hits = ($results | Where-Object { $_.Cache -eq "HIT" }).Count

Write-Host "Total: $Total"
Write-Host "Success: $($ok.Count)"
Write-Host "Failed: $($Total - $ok.Count)"
Write-Host "Cache Hits: $hits ($([math]::Round($hits/$Total*100,1))%)"
Write-Host "Duration: $([math]::Round($duration,2))s"
Write-Host "RPS: $([math]::Round($Total/$duration,1))"
Write-Host ""

if ($latencies.Count -gt 0) {
    $c = $latencies.Count
    Write-Host "Latency (ms):" -ForegroundColor Yellow
    Write-Host "  Avg: $([math]::Round(($latencies | Measure-Object -Average).Average,1))"
    Write-Host "  Min: $($latencies[0])"
    Write-Host "  Max: $($latencies[-1])"
    Write-Host "  P50: $($latencies[[int]($c*0.5)])"
    Write-Host "  P90: $($latencies[[int]($c*0.9)])"
    Write-Host "  P99: $($latencies[[int]($c*0.99)])"
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
