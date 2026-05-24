#!/bin/sh
set -eu

iptables -P OUTPUT DROP
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -o tun+ -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

if [ -n "${trusted_ip:-}" ] && [ -n "${trusted_port:-}" ]; then
  iptables -A OUTPUT -o eth0 -p tcp -d "$trusted_ip" --dport "$trusted_port" -j ACCEPT
fi

exit 0
