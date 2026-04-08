# NATMap API 并发性能测试脚本
# 使用 PowerShell 测试 /api/get 接口的并发性能

param(
    [string]$BaseUrl = "https://nm.kszhc.top",
    [int]$TenantId = 3,
    [int]$AppId = 3,
    [int]$ConcurrentRequests = 10,    # 并发请求数
    [int]$TotalRequests = 100,         # 总请求数
    [int]$TimeoutSeconds = 30          # 超时时间
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NATMap API 并发性能测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "测试参数:" -ForegroundColor Yellow
Write-Host "  URL: $BaseUrl/api/get?tenant_id=$TenantId&app_id=$AppId"
Write-Host "  并发数: $ConcurrentRequests"
Write-Host "  总请求数: $TotalRequests"
Write-Host "  超时: ${TimeoutSeconds}秒"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

# 测试结果存储
$Results = [System.Collections.ArrayList]::new()
$CacheHits = 0
$CacheMisses = 0
$Errors = 0

# 创建同步对象用于线程安全
$SyncLock = [System.Object]::new()

# 定义测试函数
function Test-ApiRequest {
    param([int]$RequestId)
    
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $Url = "$BaseUrl/api/get?tenant_id=$TenantId&app_id=$AppId"
    
    try {
        $Response = Invoke-RestMethod -Uri $Url -Method GET -TimeoutSec $TimeoutSeconds
        $Stopwatch.Stop()
        
        $Latency = $Stopwatch.ElapsedMilliseconds
        $CacheStatus = if ($Response._cache -eq "HIT") { "HIT" } elseif ($Response._cache -like "MISS*") { "MISS" } else { "UNKNOWN" }
        
        $Result = [PSCustomObject]@{
            RequestId = $RequestId
            LatencyMs = $Latency
            CacheStatus = $CacheStatus
            Success = $true
            Error = $null
            Timestamp = Get-Date -Format "HH:mm:ss.fff"
        }
        
        # 更新统计（线程安全）
        [void][System.Threading.Monitor]::Enter($SyncLock)
        try {
            [void]$Results.Add($Result)
            if ($CacheStatus -eq "HIT") { $script:CacheHits++ }
            elseif ($CacheStatus -eq "MISS") { $script:CacheMisses++ }
        }
        finally {
            [System.Threading.Monitor]::Exit($SyncLock)
        }
        
        # 显示进度
        if ($RequestId % 10 -eq 0) {
            Write-Host "." -NoNewline -ForegroundColor Green
        }
    }
    catch {
        $Stopwatch.Stop()
        
        $Result = [PSCustomObject]@{
            RequestId = $RequestId
            LatencyMs = $Stopwatch.ElapsedMilliseconds
            CacheStatus = "ERROR"
            Success = $false
            Error = $_.Exception.Message
            Timestamp = Get-Date -Format "HH:mm:ss.fff"
        }
        
        [void][System.Threading.Monitor]::Enter($SyncLock)
        try {
            [void]$Results.Add($Result)
            $script:Errors++
        }
        finally {
            [System.Threading.Monitor]::Exit($SyncLock)
        }
        
        Write-Host "X" -NoNewline -ForegroundColor Red
    }
}

# 开始测试
$TestStartTime = Get-Date
Write-Host "开始测试..." -ForegroundColor Yellow

# 使用 RunspacePool 实现并发
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $ConcurrentRequests)
$RunspacePool.Open()

$Runspaces = @()

for ($i = 1; $i -le $TotalRequests; $i++) {
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    
    [void]$PowerShell.AddScript({
        param($RequestId, $BaseUrl, $TenantId, $AppId, $TimeoutSeconds, $SyncLock, [ref]$Results, [ref]$CacheHits, [ref]$CacheMisses, [ref]$Errors)
        
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $Url = "$BaseUrl/api/get?tenant_id=$TenantId&app_id=$AppId"
        
        try {
            $Response = Invoke-RestMethod -Uri $Url -Method GET -TimeoutSec $TimeoutSeconds
            $Stopwatch.Stop()
            
            $Latency = $Stopwatch.ElapsedMilliseconds
            $CacheStatus = if ($Response._cache -eq "HIT") { "HIT" } elseif ($Response._cache -like "MISS*") { "MISS" } else { "UNKNOWN" }
            
            $Result = [PSCustomObject]@{
                RequestId = $RequestId
                LatencyMs = $Latency
                CacheStatus = $CacheStatus
                Success = $true
                Error = $null
            }
            
            return @{ Result = $Result; Type = 'Success'; CacheStatus = $CacheStatus }
        }
        catch {
            $Stopwatch.Stop()
            
            $Result = [PSCustomObject]@{
                RequestId = $RequestId
                LatencyMs = $Stopwatch.ElapsedMilliseconds
                CacheStatus = "ERROR"
                Success = $false
                Error = $_.Exception.Message
            }
            
            return @{ Result = $Result; Type = 'Error' }
        }
    })
    
    [void]$PowerShell.AddArgument($i)
    [void]$PowerShell.AddArgument($BaseUrl)
    [void]$PowerShell.AddArgument($TenantId)
    [void]$PowerShell.AddArgument($AppId)
    [void]$PowerShell.AddArgument($TimeoutSeconds)
    [void]$PowerShell.AddArgument($SyncLock)
    [void]$PowerShell.AddArgument([ref]$Results)
    [void]$PowerShell.AddArgument([ref]$CacheHits)
    [void]$PowerShell.AddArgument([ref]$CacheMisses)
    [void]$PowerShell.AddArgument([ref]$Errors)
    
    $Runspace = [PSCustomObject]@{ 
        Pipe = $PowerShell
        Status = $PowerShell.BeginInvoke()
    }
    
    $Runspaces += $Runspace
    
    # 显示进度
    if ($i % 10 -eq 0) {
        Write-Host "." -NoNewline -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "等待所有请求完成..." -ForegroundColor Yellow

# 等待所有任务完成
$Runspaces | ForEach-Object { 
    $_.Pipe.EndInvoke($_.Status) | ForEach-Object {
        [void]$Results.Add($_.Result)
        if ($_.Type -eq 'Success') {
            if ($_.CacheStatus -eq 'HIT') { $CacheHits++ }
            elseif ($_.CacheStatus -eq 'MISS') { $CacheMisses++ }
        }
        else {
            $Errors++
        }
    }
    $_.Pipe.Dispose()
}

$RunspacePool.Close()
$RunspacePool.Dispose()

$TestEndTime = Get-Date
$Duration = ($TestEndTime - $TestStartTime).TotalSeconds

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "测试结果" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 计算统计信息
$SuccessResults = $Results | Where-Object { $_.Success -eq $true }
$Latencies = $SuccessResults | Select-Object -ExpandProperty LatencyMs

if ($Latencies.Count -gt 0) {
    $SortedLatencies = $Latencies | Sort-Object
    $Count = $SortedLatencies.Count
    
    $Stats = [PSCustomObject]@{
        "总请求数" = $TotalRequests
        "成功请求" = $SuccessResults.Count
        "失败请求" = $Errors
        "缓存命中" = $CacheHits
        "缓存未命中" = $CacheMisses
        "缓存命中率" = "{0:P1}" -f ($CacheHits / $TotalRequests)
        "总耗时(秒)" = "{0:F2}" -f $Duration
        "平均RPS" = "{0:F1}" -f ($TotalRequests / $Duration)
        "平均延迟(ms)" = "{0:F1}" -f ($Latencies | Measure-Object -Average).Average
        "最小延迟(ms)" = ($Latencies | Measure-Object -Minimum).Minimum
        "最大延迟(ms)" = ($Latencies | Measure-Object -Maximum).Maximum
        "P50延迟(ms)" = $SortedLatencies[[int]($Count * 0.5)]
        "P90延迟(ms)" = $SortedLatencies[[int]($Count * 0.9)]
        "P95延迟(ms)" = $SortedLatencies[[int]($Count * 0.95)]
        "P99延迟(ms)" = $SortedLatencies[[int]($Count * 0.99)]
    }
    
    $Stats | Format-List
    
    # 延迟分布
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "延迟分布" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $Ranges = @(
        @{ Name = "0-10ms"; Min = 0; Max = 10 },
        @{ Name = "10-20ms"; Min = 10; Max = 20 },
        @{ Name = "20-50ms"; Min = 20; Max = 50 },
        @{ Name = "50-100ms"; Min = 50; Max = 100 },
        @{ Name = "100-200ms"; Min = 100; Max = 200 },
        @{ Name = ">200ms"; Min = 200; Max = [int]::MaxValue }
    )
    
    foreach ($Range in $Ranges) {
        $CountInRange = ($Latencies | Where-Object { $_ -ge $Range.Min -and $_ -lt $Range.Max }).Count
        $Percentage = "{0:P1}" -f ($CountInRange / $Latencies.Count)
        $Bar = "█" * [math]::Round($CountInRange / $Latencies.Count * 50)
        Write-Host ("{0,-12} {1,6} ({2,6}) {3}" -f $Range.Name, $CountInRange, $Percentage, $Bar)
    }
}
else {
    Write-Host "没有成功的请求" -ForegroundColor Red
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan

# 保存详细结果到文件（可选）
$OutputFile = "benchmark-result-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
$Results | Export-Csv -Path $OutputFile -NoTypeInformation
Write-Host "详细结果已保存到: $OutputFile" -ForegroundColor Green
