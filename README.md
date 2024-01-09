## IPV6GateWayRefresher
自动刷新 IPv6 网关，用于在 SLAAC 分配 IPv6 地址的网络中，保持默认网关不会丢失（通常在校园网环境会出现该问题）。
此外，该脚本还会在开机后禁用再启用全部网卡，以强制触发重新连接，只用来解决我的网络环境下，电脑重启后 IPv6 无法使用的问题，如果不需要，可以注释掉前面的几行。

## 开机启动
在任务计划程序中启用以下任务，设置为登录时执行，并且要以管理员权限执行

```powershell
powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File "path\to\IPV6GateWayRefresher.ps1"
```