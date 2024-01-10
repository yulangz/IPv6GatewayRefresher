# ����Ҫ����������ӿ���
$netName = "��̫��"
$logPath = Join-Path -Path $PSScriptRoot -ChildPath "log.txt"
$url = "test6.ustc.edu.cn"

function Clear-LargeFile {
    param (
        [string]$FilePath
    )

    # ����ļ��Ƿ����
    if (Test-Path -Path $FilePath) {
        # ��ȡ�ļ���С
        $fileSize = (Get-Item -Path $FilePath).Length

        # ����ļ���С�Ƿ񳬹� 1MB��1MB = 1 * 1024 * 1024 �ֽڣ�
        if ($fileSize -gt 1MB) {
            # ����ļ�
            Set-Content -Path $FilePath -Value $null
        }
    }
    else {
        Write-Host "�ļ�������: $FilePath"
    }
}

# �����ȴ�������������
Start-Sleep -Seconds 10

# ���������������Ī����������⣬����ԭ������������
Get-NetAdapter | Disable-NetAdapter -Confirm:$false
Start-Sleep -Seconds 8
Get-NetAdapter | Enable-NetAdapter -Confirm:$false

Clear-LargeFile -FilePath $logPath
Add-Content -Path $logPath -Value "IPv6 Gateway Refresher started at $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"

# �������е�ѭ��
while ($true) {
    try {
        # ��ȡ����ӿڵ� Index
        $interfaceIndex = (Get-NetAdapter -Name $netName).ifIndex

        # �Ȳ���һ�� ipv6 ����ͨ�ԣ������ͨ����ô��������
        try {
            $ping = Test-Connection -ComputerName $url -Count 1 -ErrorAction Stop
            # ����ɹ�����ִ���κβ���
        }
        catch {
            Get-NetAdapter | Disable-NetAdapter -Confirm:$false
            Start-Sleep -Seconds 8
            Get-NetAdapter | Enable-NetAdapter -Confirm:$false
        }

        # ��ȡĬ�����ص�ʣ����Чʱ��
        $validLifetime = Get-NetRoute -AddressFamily IPv6 -InterfaceIndex $interfaceIndex |
                         Where-Object { $_.DestinationPrefix -Eq "::/0" } |
                         Select-Object -ExpandProperty ValidLifetime

        # ������ص�ʣ����Чʱ��
        if ([int]$validLifetime.TotalSeconds -gt 300) {
            # �����Чʱ�����5���ӣ���ȴ�ֱ��ʣ��ʱ��Ϊ5����
            Clear-LargeFile -FilePath $logPath
            Add-Content -Path $logPath -Value "Waiting for $validLifetime to expire"
            Start-Sleep -Seconds ([int]($validLifetime.TotalSeconds - 300))
        } else {
            # ���û��Ĭ�����ػ���Чʱ��С��5���ӣ����� RS ����
            Clear-LargeFile -FilePath $logPath
            Add-Content -Path $logPath -Value "Sending RS"
            python -c "from scapy.all import *; pkt = IPv6(dst='ff02::2')/ICMPv6ND_RS(); send(pkt)"
        }
    } catch {
        Write-Error "��������$_"
    }

    # �����ȴ����������ռ����Դ
    Start-Sleep -Seconds 10
}
