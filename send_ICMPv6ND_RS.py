from scapy.all import *

# 构造IPv6和ICMPv6路由请求报文
pkt = IPv6(dst="ff02::2")/ICMPv6ND_RS()
send(pkt)
