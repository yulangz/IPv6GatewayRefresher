# 设置要监听的网络接口名
$netName = "以太网"
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "log.txt"
$url = "test6.ustc.edu.cn"

function Clear-LargeFile {
    param (
        [string]$FilePath
    )

    # 检查文件是否存在
    if (Test-Path -Path $FilePath) {
        # 获取文件大小
        $fileSize = (Get-Item -Path $FilePath).Length

        # 检查文件大小是否超过 1MB（1MB = 1 * 1024 * 1024 字节）
        if ($fileSize -gt 1MB) {
            # 清空文件
            Set-Content -Path $FilePath -Value $null
        }
    }
    else {
        Write-Host "文件不存在: $FilePath"
    }
}

# 开机等待联网后再运行
Start-Sleep -Seconds 10

# 断网再联网，解决莫名其妙的问题，怀疑原因在网关那里
Get-NetAdapter | Disable-NetAdapter -Confirm:$false
Start-Sleep -Seconds 8
Get-NetAdapter | Enable-NetAdapter -Confirm:$false

Clear-LargeFile -FilePath $logPath
Add-Content -Path $logPath -Value "IPv6 Gateway Refresher started at $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"

# 持续运行的循环
while ($true) {
    try {
        # 获取网络接口的 Index
        $interfaceIndex = (Get-NetAdapter -Name $netName).ifIndex

        # 先测试一下 ipv6 的连通性，如果不通，那么重启网卡
        try {
            $ping = Test-Connection -ComputerName $url -Count 1 -ErrorAction Stop
            # 如果成功，不执行任何操作
        }
        catch {
            Get-NetAdapter | Disable-NetAdapter -Confirm:$false
            Start-Sleep -Seconds 8
            Get-NetAdapter | Enable-NetAdapter -Confirm:$false
        }

        # 获取默认网关的剩余有效时间
        $validLifetime = Get-NetRoute -AddressFamily IPv6 -InterfaceIndex $interfaceIndex |
                         Where-Object { $_.DestinationPrefix -Eq "::/0" } |
                         Select-Object -ExpandProperty ValidLifetime

        # 检查网关的剩余有效时间
        if ([int]$validLifetime.TotalSeconds -gt 300) {
            # 如果有效时间大于5分钟，则等待直到剩余时间为5分钟
            Clear-LargeFile -FilePath $logPath
            Add-Content -Path $logPath -Value "Waiting for $validLifetime to expire"
            Start-Sleep -Seconds ([int]($validLifetime.TotalSeconds - 300))
        } else {
            # 如果没有默认网关或有效时间小于5分钟，发送 RS 报文
            Clear-LargeFile -FilePath $logPath
            Add-Content -Path $logPath -Value "Sending RS"
            python -c "from scapy.all import *; pkt = IPv6(dst='ff02::2')/ICMPv6ND_RS(); send(pkt)"
        }
    } catch {
        Write-Error "发生错误：$_"
    }

    # 稍作等待，避免过度占用资源
    Start-Sleep -Seconds 10
}
