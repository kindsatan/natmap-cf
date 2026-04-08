# NATMap API 并发性能测试脚本
# 修复编码和语法问题

param(
    [string]$BaseUrl = "https://nm.kszhc.top",
    [int]$TenantId = 3,
    [int]$AppId = 3,
    [int]$ConcurrentRequests = 10,
    [int]$TotalRequests = 100,
    [int]$TimeoutSeconds = 30
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NATMap API Concurrent Performance Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test Parameters:" -ForegroundColor Yellow
Write-Host "  URL: ${BaseUrl}/api/get?tenant_id=${TenantId}&app_id=${AppId}"
Write-Host "  Concurrent: $ConcurrentRequests"
Write-Host "  Total Requests: $TotalRequests"
Write-Host "  Timeout: ${TimeoutSeconds}s"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

# 存储结果
$script:Results = [System.Collections.ArrayList]::new()
$script:CacheHits = 0
$script:CacheMisses = 0
$script:Errors = 0
$SyncLock = [System.Object]::new()

# 测试函数
function Test-ApiRequest {
    param([int]$RequestId, [string]$Url, [int]$Timeout)
    
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod -Uri $Url -Method GET -TimeoutSec $Timeout
        $sw.Stop()
        
        $latency = $sw.ElapsedMilliseconds
        $cacheStatus = if ($resp._cache -eq "HIT") { "HIT" } elseif ($resp._cache -like "MISS*") { "MISS" } else { "UNKNOWN" }
        
        return @{
            RequestId = $RequestId
            LatencyMs = $latency
            CacheStatus = $cacheStatus
            Success = $true
            Error = $null
        }
    }
    catch {
        $sw.Stop()
        return @{
            RequestId = $RequestId
            LatencyMs = $sw.ElapsedMilliseconds
            CacheStatus = "ERROR"
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

# 开始测试
$testStart = Get-Date
Write-Host "Starting test..." -ForegroundColor Yellow

# 使用 ForEach-Object -Parallel (PowerShell 7+) 或顺序执行
$Url = "${BaseUrl}/api/get?tenant_id=${TenantId}&app_id=${AppId}"

if ($PSVersionTable.PSVersion.Major -ge 7) {
    # PowerShell 7+ 使用并行处理
    1..$TotalRequests | ForEach-Object -Parallel {
        $result = & ${using:function:Test-ApiRequest} -RequestId $_ -Url ${using:Url} -Timeout ${using:TimeoutSeconds}
        
        [void][System.Threading.Monitor]::Enter(${using:SyncLock})
        try {
            [void]${using:script:Results}.Add($result)
            if ($result.CacheStatus -eq "HIT") { ${using:script:CacheHits}++ }
            elseif ($result.CacheStatus -eq "MISS") { ${using:script:CacheMisses}++ }
            else { ${using:script:Errors}++ }
        }
        finally {
            [System.Threading.Monitor]::Exit(${using:SyncLock})
        }
        
        if ($_ % 10 -eq 0) { Write-Host "." -NoNewline -ForegroundColor Green }
    } -ThrottleLimit $ConcurrentRequests
}
else {
    # PowerShell 5.1 使用顺序执行
    for ($i = 1; $i -le $TotalRequests; $i++) {
        $result = Test-ApiRequest -RequestId $i -Url $Url -Timeout $TimeoutSeconds
        
        [void]$script:Results.Add($result)
        if ($result.CacheStatus -eq "HIT") { $script:CacheHits++ }
        elseif ($result.CacheStatus -eq "MISS") { $script:CacheMisses++ }
        else { $script:Errors++ }
        
        if ($i % 10 -eq 0) { Write-Host "." -NoNewline -ForegroundColor Green }
    }
}

$testEnd = Get-Date
$duration = ($testEnd - $testStart).TotalSeconds

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Results" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 统计
$successResults = $script:Results | Where-Object { $_.Success -eq $true }
$latencies = $successResults | ForEach-Object { $_.LatencyMs } | Sort-Object

if ($latencies.Count -gt 0) {
    $count = $latencies.Count
    
    Write-Host "Total Requests: $TotalRequests"
    Write-Host "Successful: $($successResults.Count)"
    Write-Host "Failed: $script:Errors"
    Write-Host "Cache Hits: $script:CacheHits ($([math]::Round($script:CacheHits / $TotalRequests * 100, 1))%)"
    Write-Host "Cache Misses: $script:CacheMisses"
    Write-Host "Total Time: $([math]::Round($duration, 2)) seconds"
    Write-Host "Avg RPS: $([math]::Round($TotalRequests / $duration, 1))"
    Write-Host ""
    Write-Host "Latency Statistics (ms):" -ForegroundColor Yellow
    Write-Host "  Average: $([math]::Round(($latencies | Measure-Object -Average).Average, 1))"
    Write-Host "  Min: $($latencies | Measure-Object -Minimum | Select-Object -ExpandProperty Minimum)"
    Write-Host "  Max: $($latencies | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum)"
    Write-Host "  P50: $($latencies[[int]($count * 0.5)])"
    Write-Host "  P90: $($latencies[[int]($count * 0.9)])"
    Write-Host "  P95: $($latencies[[int]($count * 0.95)])"
    Write-Host "  P99: $($latencies[[int]($count * 0.99)])"
    
    # 延迟分布
    Write-Host ""
    Write-Host "Latency Distribution:" -ForegroundColor Yellow
    $ranges = @(
        @{ Name = "0-10ms"; Min = 0; Max = 10 },
        @{ Name = "10-20ms"; Min = 10; Max = 20 },
        @{ Name = "20-50ms"; Min = 20; Max = 50 },
        @{ Name = "50-100ms"; Min = 50; Max = 100 },
        @{ Name = "100-200ms"; Min = 100; Max = 200 },
        @{ Name = ">200ms"; Min = 200; Max = 99999 }
    )
    
    foreach ($range in $ranges) {
        $countInRange = ($latencies | Where-Object { $_ -ge $range.Min -and $_ -lt $range.Max }).Count
        $percentage = [math]::Round($countInRange / $count * 100, 1)
        $bar = "#" * [math]::Round($percentage / 2)
        Write-Host ("  {0,-10} {1,4} ({2,5}%) {3}" -f $range.Name, $countInRange, $percentage, $bar)
    }
}
else {
    Write-Host "No successful requests!" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
